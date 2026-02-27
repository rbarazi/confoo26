/**
 * Minimal CDP client for Chrome running as a Docker sidecar.
 *
 * Supports two connection modes (auto-detected):
 *
 *   1. Direct CDP — browserless/chromium or any image exposing /json/version
 *      Connects directly to the browser-level WebSocket debugger URL, then
 *      attaches to (or creates) a page target.
 *
 *   2. Selenium Grid — seleniarm/standalone-chromium (or selenium/standalone-chrome)
 *      Creates a WebDriver session, extracts the `se:cdp` WebSocket URL from
 *      the session capabilities, and connects to that. The se:cdp endpoint is
 *      browser-level (like direct CDP), so we still need Target.attachToTarget
 *      to get a flat session for page-level commands.
 *
 * The session state is persisted to /tmp/.chrome-session.json so subsequent
 * script invocations reuse the same browser tab.
 */

import { readFileSync, writeFileSync, existsSync, unlinkSync } from "node:fs";

const CHROME_URL = process.env.CHROME_URL || "http://chrome:4444";
const SESSION_FILE = "/tmp/.chrome-session.json";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[cdp]", ...args) : () => {};

// ---------------------------------------------------------------------------
// Endpoint discovery
// ---------------------------------------------------------------------------

/** Try direct Chrome DevTools Protocol endpoint (/json/version). */
async function tryDirectCDP() {
  try {
    const res = await fetch(`${CHROME_URL}/json/version`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!res.ok) return null;
    const info = await res.json();

    // Selenium Grid also responds to /json/version with an error body
    if (info.value?.error || !info.webSocketDebuggerUrl) return null;

    let wsUrl = info.webSocketDebuggerUrl;

    // Rewrite host to match CHROME_URL so it's reachable from this container
    const target = new URL(CHROME_URL);
    const u = new URL(wsUrl);
    u.protocol = "ws:";
    u.hostname = target.hostname;
    u.port = target.port;
    wsUrl = u.toString();

    log("direct CDP endpoint:", wsUrl);
    return { mode: "direct", cdpUrl: wsUrl };
  } catch {
    return null;
  }
}

/** Try Selenium Grid WebDriver endpoint (POST /session). */
async function trySeleniumGrid() {
  const res = await fetch(`${CHROME_URL}/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      capabilities: {
        alwaysMatch: {
          browserName: "chrome",
          "goog:chromeOptions": {
            args: ["--disable-search-engine-choice-screen"],
          },
        },
      },
    }),
    signal: AbortSignal.timeout(30000),
  });

  if (!res.ok) {
    throw new Error(`Selenium session failed: ${res.status} ${await res.text()}`);
  }

  const { value } = await res.json();
  let cdpUrl = value.capabilities?.["se:cdp"];

  if (cdpUrl) {
    const target = new URL(CHROME_URL);
    const u = new URL(cdpUrl);
    u.hostname = target.hostname;
    u.port = target.port;
    cdpUrl = u.toString();
  }

  log("selenium session:", value.sessionId, "cdp:", cdpUrl);
  return {
    mode: "selenium",
    sessionId: value.sessionId,
    cdpUrl,
  };
}

async function sessionAlive(session) {
  if (session.mode === "direct") {
    try {
      const res = await fetch(`${CHROME_URL}/json/version`, {
        signal: AbortSignal.timeout(2000),
      });
      if (!res.ok) return false;
      const info = await res.json();
      return !!info.webSocketDebuggerUrl;
    } catch {
      return false;
    }
  }

  // Selenium mode — check session is still valid
  try {
    const res = await fetch(`${CHROME_URL}/session/${session.sessionId}/url`, {
      signal: AbortSignal.timeout(3000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function ensureSession() {
  if (existsSync(SESSION_FILE)) {
    try {
      const data = JSON.parse(readFileSync(SESSION_FILE, "utf8"));
      if (await sessionAlive(data)) {
        log("reusing session:", data.mode);
        return data;
      }
    } catch {}
  }

  log("discovering endpoint...");
  let session = await tryDirectCDP();
  if (!session) {
    log("direct CDP unavailable, trying Selenium Grid...");
    session = await trySeleniumGrid();
  }

  writeFileSync(SESSION_FILE, JSON.stringify(session));
  return session;
}

// ---------------------------------------------------------------------------
// CDP over WebSocket
// ---------------------------------------------------------------------------

function connectWebSocket(url, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    const timer = setTimeout(() => {
      ws.close();
      reject(new Error(`WebSocket connection timeout (${timeout}ms)`));
    }, timeout);

    ws.addEventListener("open", () => {
      clearTimeout(timer);
      resolve(ws);
    });

    ws.addEventListener("error", (e) => {
      clearTimeout(timer);
      reject(new Error(`WebSocket error: ${e.message || "connection failed"}`));
    });
  });
}

class CDP {
  #ws;
  #seq = 0;
  #callbacks = new Map();
  #sessionId = null; // CDP flatSession ID for target (not WebDriver session)

  constructor(ws) {
    this.#ws = ws;
    ws.addEventListener("message", (event) => {
      const raw = typeof event.data === "string" ? event.data : event.data.toString();
      const msg = JSON.parse(raw);
      if (msg.id != null && this.#callbacks.has(msg.id)) {
        const cb = this.#callbacks.get(msg.id);
        this.#callbacks.delete(msg.id);
        if (msg.error) cb.reject(new Error(msg.error.message));
        else cb.resolve(msg.result);
      }
    });
  }

  send(method, params = {}, timeout = 30000) {
    return new Promise((resolve, reject) => {
      const id = ++this.#seq;
      this.#callbacks.set(id, { resolve, reject });
      const msg = { id, method, params };
      if (this.#sessionId) msg.sessionId = this.#sessionId;
      this.#ws.send(JSON.stringify(msg));
      setTimeout(() => {
        if (this.#callbacks.has(id)) {
          this.#callbacks.delete(id);
          reject(new Error(`Timeout (${timeout}ms): ${method}`));
        }
      }, timeout);
    });
  }

  /**
   * For direct CDP (browser-level WebSocket), we need to attach to a page
   * target to run most commands. This finds the first page or creates one.
   */
  async attachToPage() {
    const { targetInfos } = await this.send("Target.getTargets");
    let page = targetInfos.find((t) => t.type === "page");

    if (!page) {
      const { targetId } = await this.send("Target.createTarget", {
        url: "about:blank",
      });
      page = { targetId };
    }

    const { sessionId } = await this.send("Target.attachToTarget", {
      targetId: page.targetId,
      flatten: true,
    });
    this.#sessionId = sessionId;
    log("attached to page target:", page.targetId);
  }

  async navigate(url) {
    // Both modes use flat sessions via Target.attachToTarget, so CDP events
    // work in both. Enable Page domain, start navigation, wait for load.
    await this.send("Page.enable");
    const loadPromise = new Promise((resolve) => {
      const handler = (event) => {
        const raw = typeof event.data === "string" ? event.data : event.data.toString();
        const msg = JSON.parse(raw);
        if (msg.method === "Page.loadEventFired") {
          this.#ws.removeEventListener("message", handler);
          resolve();
        }
      };
      this.#ws.addEventListener("message", handler);
    });
    await this.send("Page.navigate", { url });
    await Promise.race([
      loadPromise,
      new Promise((_, rej) => setTimeout(() => rej(new Error("Page load timeout (30s)")), 30000)),
    ]);
  }

  async evaluate(expression) {
    const { result, exceptionDetails } = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (exceptionDetails) {
      throw new Error(exceptionDetails.exception?.description || exceptionDetails.text);
    }
    return result.value;
  }

  async screenshot() {
    const { data } = await this.send("Page.captureScreenshot", { format: "png" });
    return Buffer.from(data, "base64");
  }

  close() {
    this.#ws.close();
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export async function connect(timeout = 5000) {
  const session = await ensureSession();
  if (!session.cdpUrl) {
    throw new Error(
      "No CDP endpoint available. For Selenium Grid, check that se:cdp is in the session capabilities."
    );
  }

  const ws = await connectWebSocket(session.cdpUrl, timeout);
  const cdp = new CDP(ws);

  // Both modes connect at the browser level — attach to a page target
  // to get a flat session for page-level CDP commands.
  await cdp.attachToPage();

  return cdp;
}

export async function closeSession() {
  if (!existsSync(SESSION_FILE)) return;
  let session;
  try {
    session = JSON.parse(readFileSync(SESSION_FILE, "utf8"));
  } catch {
    unlinkSync(SESSION_FILE);
    return;
  }

  if (session.mode === "selenium" && session.sessionId) {
    try {
      await fetch(`${CHROME_URL}/session/${session.sessionId}`, { method: "DELETE" });
    } catch {}
  }

  unlinkSync(SESSION_FILE);
}

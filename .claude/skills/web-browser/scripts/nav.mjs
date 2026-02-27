#!/usr/bin/env node

import { connect } from "./cdp.mjs";

const url = process.argv[2];
const newTab = process.argv[3] === "--new";

if (!url) {
  console.log("Usage: nav.mjs <url> [--new]");
  console.log("\nExamples:");
  console.log("  nav.mjs https://example.com        # Navigate current tab");
  console.log("  nav.mjs https://example.com --new   # Open in new tab");
  process.exit(1);
}

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (45s)");
  process.exit(1);
}, 45000);

try {
  const cdp = await connect();

  if (newTab) {
    await cdp.send("Target.createTarget", { url });
    console.log("Opened in new tab:", url);
  } else {
    await cdp.navigate(url);
    console.log("Navigated to:", url);
  }

  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

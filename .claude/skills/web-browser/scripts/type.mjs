#!/usr/bin/env node

import { connect } from "./cdp.mjs";

const selector = process.argv[2];
const text = process.argv.slice(3).join(" ");

if (!selector || !text) {
  console.log("Usage: type.mjs '<css-selector>' '<text>'");
  console.log("\nExamples:");
  console.log("  type.mjs '#email' 'user@example.com'");
  console.log("  type.mjs 'input[name=search]' 'hello world'");
  process.exit(1);
}

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  const cdp = await connect();

  // Focus the element
  await cdp.evaluate(`(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) throw new Error('Element not found: ${selector.replace(/'/g, "\\'")}');
    el.focus();
  })()`);

  // Clear existing value
  await cdp.evaluate(`(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    el.value = '';
    el.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);

  // Type each character via CDP Input domain
  for (const char of text) {
    await cdp.send("Input.dispatchKeyEvent", { type: "keyDown", text: char });
    await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", text: char });
  }

  console.log("Typed into:", selector);
  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

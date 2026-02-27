#!/usr/bin/env node

import { connect } from "./cdp.mjs";

const selector = process.argv[2];
if (!selector) {
  console.log("Usage: click.mjs '<css-selector>'");
  console.log("\nExamples:");
  console.log("  click.mjs 'button[type=submit]'");
  console.log("  click.mjs '#login-btn'");
  console.log("  click.mjs 'a.nav-link'");
  process.exit(1);
}

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  const cdp = await connect();

  // Find the element and get its center coordinates
  const bounds = await cdp.evaluate(`(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) throw new Error('Element not found: ${selector.replace(/'/g, "\\'")}');
    const rect = el.getBoundingClientRect();
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  })()`);

  // Simulate mouse click via CDP Input domain
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed",
    x: bounds.x,
    y: bounds.y,
    button: "left",
    clickCount: 1,
  });
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased",
    x: bounds.x,
    y: bounds.y,
    button: "left",
    clickCount: 1,
  });

  console.log("Clicked:", selector);
  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

#!/usr/bin/env node

import { connect } from "./cdp.mjs";

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  const cdp = await connect();
  const text = await cdp.evaluate("document.body.innerText");
  console.log(text);
  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

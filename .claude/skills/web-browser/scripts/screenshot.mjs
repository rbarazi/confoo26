#!/usr/bin/env node

import { tmpdir } from "node:os";
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import { connect } from "./cdp.mjs";

const outPath = process.argv[2];

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  const cdp = await connect();
  const data = await cdp.screenshot();

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filepath = outPath || join(tmpdir(), `screenshot-${timestamp}.png`);
  writeFileSync(filepath, data);

  // Print the path so Claude can read the image
  console.log(filepath);

  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

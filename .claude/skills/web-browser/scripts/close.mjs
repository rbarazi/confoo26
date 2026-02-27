#!/usr/bin/env node

import { closeSession } from "./cdp.mjs";

try {
  await closeSession();
  console.log("Session closed");
} catch (e) {
  console.error(e.message);
  process.exit(1);
}

#!/usr/bin/env node

import { connect } from "./cdp.mjs";

const code = process.argv.slice(2).join(" ");
if (!code) {
  console.log("Usage: eval.mjs '<javascript>'");
  console.log("\nExamples:");
  console.log('  eval.mjs "document.title"');
  console.log("  eval.mjs \"document.querySelectorAll('a').length\"");
  console.log("  eval.mjs \"JSON.stringify([...document.querySelectorAll('a')].map(a => ({text: a.textContent.trim(), href: a.href})))\"");
  process.exit(1);
}

const globalTimeout = setTimeout(() => {
  console.error("Global timeout exceeded (45s)");
  process.exit(1);
}, 45000);

try {
  const cdp = await connect();

  const expression = `(async () => { return (${code}); })()`;
  const result = await cdp.evaluate(expression);

  if (Array.isArray(result)) {
    for (let i = 0; i < result.length; i++) {
      if (i > 0) console.log("");
      if (typeof result[i] === "object" && result[i] !== null) {
        for (const [key, value] of Object.entries(result[i])) {
          console.log(`${key}: ${value}`);
        }
      } else {
        console.log(result[i]);
      }
    }
  } else if (typeof result === "object" && result !== null) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(result);
  }

  cdp.close();
} catch (e) {
  console.error(e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}

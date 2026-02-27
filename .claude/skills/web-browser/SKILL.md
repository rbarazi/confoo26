---
name: web-browser
description: "Browse and interact with web pages using Chrome via CDP (Chrome DevTools Protocol). Use this skill whenever you need to: visually verify a web page renders correctly, check UI elements or layout, test web application behavior, take screenshots for visual inspection, fill out forms, click buttons, extract content from rendered pages, or debug frontend issues. This includes checking the local Rails app during development, verifying deploy previews, testing user-facing flows, or loading any URL the user mentions. Always reach for this skill when someone asks you to 'check', 'look at', 'open', 'browse', 'verify', or 'test' something in a browser, or when you need to confirm that a UI change you just made actually works."
---

# Web Browser

Control Chrome running as a sidecar container via CDP. The browser session
persists across script invocations so you can navigate, interact, and inspect
across multiple steps without losing state.

The user can watch the browser live at **http://localhost:7900** (noVNC, no
password).

## Scripts

All scripts live in this skill's `scripts/` directory. Run them with `node`.

### Navigate

```bash
node scripts/nav.mjs <url>          # Navigate current tab
node scripts/nav.mjs <url> --new    # Open in a new tab
```

The local Rails app is accessible from the browser at `http://rails-app:3000`
(Docker service name), not `localhost`. External URLs work normally.

### Screenshot

```bash
node scripts/screenshot.mjs [/tmp/out.png]
```

Captures the viewport as PNG. Prints the file path to stdout — use the Read
tool to view the image. If no path is given, saves to a timestamped file in
`/tmp`.

**Always take a screenshot after navigating** to confirm the page loaded.

### Evaluate JavaScript

```bash
node scripts/eval.mjs '<expression>'
```

Runs JavaScript in the page context and prints the return value. Wraps the
expression in an async IIFE so `await` works. Remember to quote the expression
in the shell.

Examples:
```bash
node scripts/eval.mjs "document.title"
node scripts/eval.mjs "document.querySelectorAll('a').length"
node scripts/eval.mjs "JSON.stringify([...document.querySelectorAll('h2')].map(el => el.textContent))"
```

### Click

```bash
node scripts/click.mjs '<css-selector>'
```

Finds the first element matching the CSS selector, calculates its center, and
dispatches a mouse click via the CDP Input domain. Use `eval.mjs` first if
you're unsure of the right selector.

### Type

```bash
node scripts/type.mjs '<css-selector>' '<text>'
```

Focuses the element, clears its value, then types the text character by
character. Useful for form fields and search boxes.

### Get Page Text

```bash
node scripts/text.mjs
```

Returns `document.body.innerText` — all visible text on the page. Quick way to
check content without parsing HTML.

### Close Session

```bash
node scripts/close.mjs
```

Closes the WebDriver session and frees the browser tab. Run this when you're
done browsing to clean up resources.

## Typical Workflow

1. Navigate to the page:
   `node scripts/nav.mjs http://rails-app:3000/some-path`
2. Screenshot to verify it loaded:
   `node scripts/screenshot.mjs /tmp/page.png` then read `/tmp/page.png`
3. Inspect or interact as needed (eval, click, type)
4. Screenshot again to verify the result
5. Close when finished: `node scripts/close.mjs`

## Tips

- **Session reuse**: A browser session is created on first use and reused for
  all subsequent commands. If Chrome restarts, the next command automatically
  creates a fresh session.
- **Selectors**: When `click.mjs` or `type.mjs` can't find an element, use
  `eval.mjs` to query the DOM and find the right selector.
- **String escaping**: Shell quoting can be tricky with JavaScript. Use double
  quotes for the outer shell argument and single quotes inside the JS, or
  vice versa.
- **Debugging**: Set `DEBUG=1` to see connection diagnostics on stderr.

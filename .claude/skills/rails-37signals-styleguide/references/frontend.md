# Frontend Reference: Stimulus, CSS, Hotwire, Accessibility

## Table of Contents
- [Stimulus Controllers Catalog](#stimulus-controllers-catalog)
- [CSS Architecture](#css-architecture)
- [Hotwire / Turbo Patterns](#hotwire--turbo-patterns)
- [Accessibility](#accessibility)

---

## Stimulus Controllers Catalog

52 controllers split 60/40 between reusable utilities and domain-specific logic. All controllers follow these rules:
- Single-purpose (one job per controller)
- Configured via Values/Classes API (no hardcoded strings)
- Event-based communication (dispatch events, don't call other controllers)
- Always clean up in `disconnect()`

### Copy-to-Clipboard (25 lines)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }
  static classes = [ "success" ]

  async copy(event) {
    event.preventDefault()
    this.reset()
    try {
      await navigator.clipboard.writeText(this.contentValue)
      this.element.classList.add(this.successClass)
    } catch {}
  }

  reset() {
    this.element.classList.remove(this.successClass)
    this.element.offsetWidth // Force reflow for animation reset
  }
}
```

Usage:
```html
<button data-controller="copy-to-clipboard"
        data-copy-to-clipboard-content-value="https://example.com"
        data-copy-to-clipboard-success-class="copied"
        data-action="click->copy-to-clipboard#copy">Copy</button>
```

### Auto-Click (7 lines)
Clicks element on connect — auto-submit forms on page load:
```javascript
export default class extends Controller {
  connect() { this.element.click() }
}
```

### Element Removal (7 lines)
```javascript
export default class extends Controller {
  remove() { this.element.remove() }
}
```

### Toggle Class (31 lines)
Toggle, add, or remove CSS classes:
```javascript
export default class extends Controller {
  static classes = [ "toggle" ]
  static targets = [ "checkbox" ]

  toggle() { this.element.classList.toggle(this.toggleClass) }
  add() { this.element.classList.add(this.toggleClass) }
  remove() { this.element.classList.remove(this.toggleClass) }
  checkAll() { this.checkboxTargets.forEach(cb => cb.checked = true) }
  checkNone() { this.checkboxTargets.forEach(cb => cb.checked = false) }
}
```

### Auto-Resize Textarea (32 lines)
```javascript
export default class extends Controller {
  static values = { minHeight: { type: Number, default: 0 } }

  connect() { this.resize() }

  resize() {
    this.element.style.height = "auto"
    const newHeight = Math.max(this.minHeightValue, this.element.scrollHeight)
    this.element.style.height = `${newHeight}px`
  }
}
```

### Dialog Controller (45 lines)
Native `<dialog>` management:
```javascript
export default class extends Controller {
  connect() { this.element.addEventListener("close", this.#onClose.bind(this)) }
  disconnect() { this.element.removeEventListener("close", this.#onClose.bind(this)) }
  open() { this.element.showModal() }
  close() { this.element.close() }
  closeOnOutsideClick(event) { if (event.target === this.element) this.close() }
  #onClose() { this.dispatch("closed") }
}
```

### Auto-Submit (28 lines)
Debounced form auto-submission:
```javascript
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }
  connect() { this.timeout = null }
  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
  submitNow() { clearTimeout(this.timeout); this.element.requestSubmit() }
  disconnect() { clearTimeout(this.timeout) }
}
```

### Local Time (40 lines)
Display times in user's local timezone with relative formatting.

### Beacon (20 lines)
Track views by pinging a URL on connect:
```javascript
export default class extends Controller {
  static values = { url: String }
  connect() { if (this.hasUrlValue) navigator.sendBeacon(this.urlValue) }
}
```

### Form Reset (12 lines)
```javascript
export default class extends Controller {
  reset() { this.element.reset() }
  resetOnSuccess(event) { if (event.detail.success) this.reset() }
}
```
Usage: `data-action="turbo:submit-end->form-reset#resetOnSuccess"`

### Character Counter (25 lines)
```javascript
export default class extends Controller {
  static targets = [ "input", "counter" ]
  static values = { max: Number }
  connect() { this.update() }
  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.counterTarget.textContent = remaining
    this.counterTarget.classList.toggle("over-limit", remaining < 0)
  }
}
```

### Hotkey Controller
Handle keyboard shortcuts:
```javascript
export default class extends Controller {
  click(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault()
      this.element.click()
    }
  }
  #shouldIgnore(event) {
    return event.defaultPrevented || event.target.closest("input, textarea, [contenteditable]")
  }
  get #isClickable() { return getComputedStyle(this.element).pointerEvents !== "none" }
}
```
Usage: `data-action="keydown.n@document->hotkey#click"`

### Navigable List
Arrow key navigation through lists:
```javascript
export default class extends Controller {
  static targets = ["item"]
  static values = { actionableItems: { type: Boolean, default: false } }

  navigate(event) {
    switch (event.key) {
      case "ArrowDown": this.#selectNext(); break
      case "ArrowUp": this.#selectPrevious(); break
      case "Enter": this.#activateCurrent(event); break
    }
  }
  // Selection management with aria-selected...
}
```

### Cached Fragment Personalization
Move user-specific styling to client-side to preserve cacheable partials:
```javascript
// initializers/current.js
class Current {
  get user() {
    const id = document.head.querySelector('meta[name="current-user-id"]')?.content
    return id ? { id: parseInt(id) } : null
  }
}
window.Current = new Current()

// controllers/personalize_controller.js
export default class extends Controller {
  static targets = ["item"]
  static classes = ["mine"]
  itemTargetConnected(element) {
    if (element.dataset.creatorId == Current.user?.id)
      element.classList.add(this.mineClass)
  }
}
```

### Stimulus Best Practices

- Use Values API over `getAttribute()` — cleaner, type-coerced
- Use camelCase in JavaScript (data attributes auto-convert)
- Always clean up in `disconnect()` — timers, listeners, observers
- Use `:self` action filter to scope events
- Extract shared helpers to modules (`helpers/date_helpers.js`)
- Dispatch events for inter-controller communication
- Use `await nextFrame()` before applying drag classes

---

## CSS Architecture

Native CSS only — no Sass, PostCSS, or Tailwind.

### Cascade Layers

```css
@layer reset, base, layout, components, utilities;

@layer reset { *, *::before, *::after { box-sizing: border-box; } }
@layer base { body { font-family: system-ui, sans-serif; line-height: 1.5; } }
@layer components { .card { } .btn { } }
@layer utilities { .hidden { display: none; } .flex { display: flex; } }
```

Later layers always win regardless of selector specificity.

### OKLCH Color Space

```css
:root {
  --lch-blue-dark: 57.02% 0.1895 260.46;
  --color-link: oklch(var(--lch-blue-dark));
}
```

### Dark Mode via Variable Overrides

```css
:root { --lch-ink-darkest: 26% 0.05 264; --lch-canvas: 100% 0 0; }
html[data-theme="dark"] { --lch-ink-darkest: 96.02% 0.0034 260; --lch-canvas: 20% 0.0195 232.58; }
@media (prefers-color-scheme: dark) {
  html:not([data-theme]) { /* same dark overrides */ }
}
```

### Component Pattern with CSS Variables

```css
.btn {
  --btn-background: var(--color-canvas);
  --btn-color: var(--color-ink);
  background-color: var(--btn-background);
  color: var(--btn-color);

  @media (any-hover: hover) { &:hover { filter: brightness(var(--btn-hover-brightness)); } }
  &[disabled] { cursor: not-allowed; opacity: 0.3; }
}
.btn--link { --btn-background: var(--color-link); --btn-color: var(--color-ink-inverted); }
```

### Modern CSS Features

- **Native nesting**: `&:hover { }`, `html[data-theme="dark"] & { }`
- **`@starting-style`**: Entry animations for dialogs
- **`color-mix()`**: Dynamic color blending
- **`:has()`**: Parent-aware styling (`.btn:has(input:checked)`)
- **Logical properties**: `padding-block`, `margin-inline-start`
- **Container queries**: `@container (width < 300px) { }`
- **`field-sizing: content`**: Auto-sizing textareas

### Naming Convention

BEM-inspired but pragmatic:
```css
.card { }
.card__header { }
.card--closed { }
```

### Design Tokens

```css
:root {
  --inline-space: 1ch;
  --block-space: 1rem;
  --text-small: 0.85rem;
  --z-popup: 10; --z-nav: 30; --z-tooltip: 50;
  --ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
}
```

### Responsive Strategy

Minimal breakpoints, mostly fluid:
```css
--main-padding: clamp(var(--inline-space), 3vw, calc(var(--inline-space) * 3));
@media (max-width: 639px) { /* Mobile */ }
@media (min-width: 640px) { /* Desktop */ }
```

### Utility Classes (~60 total)

```css
@layer utilities {
  .txt-small { font-size: var(--text-small); }
  .txt-subtle { color: var(--color-ink-dark); }
  .flex { display: flex; }
  .stack { display: flex; flex-direction: column; }
  .visually-hidden { clip-path: inset(50%); position: absolute; width: 1px; height: 1px; overflow: hidden; }
}
```

### File Organization

One file per concern (~100-300 lines):
```
app/assets/stylesheets/
├── _global.css       # Variables, layers, dark mode
├── reset.css         # Modern CSS reset
├── base.css          # Element defaults
├── layout.css        # Grid layout
├── utilities.css     # Utility classes
├── buttons.css       # .btn component
├── cards.css         # .card component
├── inputs.css        # Form controls
├── dialog.css        # Dialog animations
└── application.css   # Imports all files
```

---

## Hotwire / Turbo Patterns

### Turbo Morphing

Enable globally: `turbo_refreshes_with method: :morph, scroll: :preserve`

- Listen for `turbo:morph-element` to restore client-side state
- Use `data-turbo-permanent` for elements that shouldn't refresh
- Ensure unique IDs (duplicates break morphing)
- Set `refresh: :morph` on frames with `src`

### Turbo Frames

- Lazy-load expensive content: `turbo_frame_tag "notifications", src: path, loading: :lazy`
- Use `data-turbo-frame="_parent"` to target parent frame
- Wrap forms in frames to prevent reset on partial updates
- Respond with `turbo_stream.replace` instead of redirects

### Turbo Streams

```ruby
# Controller
render turbo_stream: [
  turbo_stream.append(:comments, @comment),
  turbo_stream_flash(notice: "Added!")
]

# Broadcasts (always scope by account for multi-tenancy)
broadcast_to [Current.account, card], target: "comments"
```

### State Persistence

- localStorage for UI preferences (expanded panels, draft content)
- Restore on `turbo:morph-element` events
- Use `nextFrame()` helper to wait for morph completion

### Common Patterns

- **Links over JavaScript** — filter chips as `<a>` tags, not JS buttons
- **POST + Turbo Streams** for state toggles (watch/unwatch)
- **Auto-save** with debouncing (3s interval)
- **Auto-submit** on form changes
- **Lazy loading on visibility** with IntersectionObserver
- **Progressive installation** — show interactive UI only after JS loads
- **Drag and drop** — focused Stimulus controller, not heavyweight sortable library

### Common Turbo Issues

| Problem | Solution |
|---------|----------|
| Timers not updating after morph | Bind to `turbo:morph-element` |
| Forms resetting on page refresh | Wrap in turbo frames |
| Flickering on replace | Use `method: :morph` |
| localStorage state lost | Restore on `turbo:morph-element` |
| CSRF tokens stale | Don't HTTP cache pages with forms |

---

## Accessibility

### ARIA Patterns

1. **`aria-hidden="true"`** on decorative icons, duplicate links, avatar images when name is present
2. **`aria-label`** on icon-only buttons (always hide the icon with `aria: { hidden: true }`)
3. **`role="group"` + `aria-label`** for related content (assignee avatars, message lists)
4. **Readable counts**: visual "5" + `.for-screen-reader` "5 comments"
5. **`aria-label` + `aria-description`** on dialogs
6. **`aria-expanded`** toggled dynamically on expandable content
7. **`aria-selected`** for custom list navigation

### Keyboard Navigation

- `event.preventDefault()` on custom keyboard shortcuts
- Reusable navigable list controller with ArrowUp/ArrowDown/Enter
- `checkVisibility()` for accurate item detection (not just `hidden` attribute)
- Support reverse navigation for bottom-stacked trays
- Reset selection when dialogs open

### Screen Reader Support

```css
.visually-hidden, .for-screen-reader {
  block-size: 1px; clip-path: inset(50%); inline-size: 1px;
  overflow: hidden; position: absolute; white-space: nowrap;
}
```

- Prefer visually-hidden text over `aria-label` for complex/formatted content
- Fix form label associations with `form.field_id(:field, value)`
- Every input needs an accessible label
- Use semantic HTML (`<h1>`, `<nav>`, `<article>`) over generic `<div>`

### Focus Management

```css
:root {
  --focus-ring-color: var(--color-link);
  --focus-ring-offset: 1px;
  --focus-ring-size: 2px;
}
:is(a, button, input, textarea):where(:focus-visible) {
  outline: var(--focus-ring-size) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}
```

- Use `:focus-visible` not `:focus` (no rings on mouse click)
- Move focus ring to parent for hidden radio/checkbox inputs (`:has(input:focus-visible)`)
- Focus first element when dialog opens; trap focus inside
- Suppress focus on readonly inputs

### Platform-Specific

- Adapt keyboard shortcuts by platform (Cmd vs Ctrl)
- Use `@media (any-hover: hover)` for hover effects (touch devices don't hover)

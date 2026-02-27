---
name: rails-37signals-styleguide
description: |
  Enforces 37signals/Basecamp/HEY Rails coding conventions when writing Ruby on Rails code. Use this skill whenever writing or reviewing Rails controllers, models, views, routes, migrations, Stimulus controllers, CSS, background jobs, tests, mailers, or any other Rails code. Also use when the user mentions "37signals style", "Basecamp patterns", "HEY patterns", "DHH style", "vanilla Rails", or asks to follow 37signals conventions. Trigger this skill for any Rails development task — it provides comprehensive guidance on architecture, patterns, frontend (Hotwire/Stimulus/CSS), backend (jobs, caching, auth, multi-tenancy), testing, and philosophy.
---

# 37signals Rails Style Guide

Transferable Rails patterns extracted from 37signals' codebases. These conventions prioritize vanilla Rails, simplicity, and shipping over abstractions and gems.

## Quick Reference: The 37signals Way

1. **Rich domain models** over service objects
2. **CRUD controllers** over custom actions
3. **Concerns** for horizontal code sharing
4. **Records as state** over boolean columns
5. **Database-backed everything** (Solid Queue/Cache/Cable — no Redis)
6. **Build it yourself** before reaching for gems
7. **Ship to learn** — prototype quality is valid for validation
8. **Vanilla Rails is plenty** — maximize what Rails gives you

## What They Deliberately Avoid

Do NOT use these gems/patterns — use the listed alternative instead:

| Avoid | Use Instead |
|-------|-------------|
| Devise | Custom passwordless magic links (~150 lines) |
| Pundit / CanCanCan | Model predicate methods (`card.editable_by?(user)`) |
| Service objects | Rich model methods (`card.close(by: user)`) |
| Form objects | Strong parameters (`params.expect(card: [...])`) |
| Decorators / Presenters | View helpers and POROs under model namespace |
| ViewComponent | ERB partials with explicit locals |
| GraphQL | REST + Turbo Streams |
| Sidekiq | Solid Queue (database-backed) |
| React / Vue | Turbo + Stimulus |
| Tailwind CSS | Native CSS with cascade layers |
| RSpec | Minitest |
| FactoryBot | Fixtures |

Before adding any gem, ask: Can vanilla Rails do this? Is the complexity worth it?

---

## Routing

Everything is CRUD. When an action doesn't fit standard verbs, create a new noun resource:

```ruby
# Turn verbs into nouns
resources :cards do
  scope module: :cards do
    resource :closure      # POST to close, DELETE to reopen
    resource :goldness     # POST to gild, DELETE to ungild
    resource :not_now      # POST to postpone
    resource :pin          # POST to pin, DELETE to unpin
    resource :watch        # POST to watch, DELETE to unwatch
    resources :comments do
      resources :reactions
    end
  end
end
```

- Use `resource` (singular) for one-per-parent relationships
- Use `scope module:` to group controllers without changing URLs
- Use `shallow: true` to avoid deep nesting
- Use `resolve` for polymorphic URL generation
- Use `params.expect(key: [...])` instead of `params.require(:key).permit(...)`
- No separate API controllers — use `respond_to` blocks in the same controller

## Controllers

Thin orchestrators calling rich models. All business logic lives in models.

```ruby
class Cards::ClosuresController < ApplicationController
  include CardScoped  # Concern provides @card, @board, render_card_replacement

  def create
    @card.close  # All logic in model
    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

**Concerns catalog** — create reusable controller behaviors:
- **Resource scoping** (CardScoped, BoardScoped) — `before_action :set_card`
- **Request context** (CurrentRequest) — populate `Current` with IP, user agent, etc.
- **Timezone** (CurrentTimezone) — `around_action` with `Time.use_zone`
- **Security** (BlockSearchEngineIndexing, RequestForgeryProtection)
- **Turbo** (TurboFlash, ViewTransitions)

**Authorization**: Model defines permission, controller checks it:
```ruby
# Model
def can_administer_card?(card) = admin? || card.creator == self

# Controller
before_action :ensure_permission, only: [:destroy]
def ensure_permission = head(:forbidden) unless Current.user.can_administer_card?(@card)
```

## Models

Rich domain models with composable concerns. Each concern is self-contained (50-150 lines) with associations, scopes, and methods:

```ruby
class Card < ApplicationRecord
  include Assignable, Closeable, Golden, Pinnable, Watchable
  belongs_to :account, default: -> { board.account }
  belongs_to :creator, class_name: "User", default: -> { Current.user }
end
```

### State as Records, Not Booleans

Instead of `closed: boolean`, create a separate record:

```ruby
class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user, optional: true
  # created_at = when, user = who
end

# Querying
Card.closed  # joins(:closure)
Card.open    # where.missing(:closure)
```

### Key Model Patterns

- **Default values via lambdas**: `belongs_to :creator, default: -> { Current.user }`
- **Minimal validations** — prefer DB constraints over AR validations
- **Bang methods**: `create!` over `create` (let it crash)
- **Sparse callbacks** — only for setup/cleanup, not business logic
- **Positive scope names**: `active` not `not_deleted`, `unpopped` not `not_popped`
- **Business-focused scopes**: `scope :golden, -> { joins(:goldness) }`
- **POROs under model namespace** for presentation logic: `Event::Description`
- **`normalizes`** for data consistency instead of `before_validation`
- **`StringInquirer`** for action predicates: `event.action.completed?`
- **Touch chains** for cache invalidation: `belongs_to :card, touch: true`
- **Counter caches** for denormalized counts
- **`Data.define`** for immutable value objects
- **Delegated types** for polymorphic associations

### Current for Request Context

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account
  attribute :http_method, :request_id, :user_agent, :ip_address
end
```

## Views

- **Turbo Streams** over redirects for partial updates
- **Morphing** (`method: :morph`) for complex replacements without flicker
- **Partials with explicit locals** — never rely on magical instance variables
- **Fragment caching** with contextual keys: `cache [card, Current.user, timezone]`
- **Touch chains** for automatic cache invalidation
- **HTTP caching** with `fresh_when etag:` — but never cache pages with forms (stale CSRF)
- **Lazy-loaded content** via Turbo Frames with `loading: :lazy`
- **User-specific content** via client-side Stimulus (not server conditionals in cached partials)
- **DOM IDs** via Rails `dom_id` helper
- **Helpers** take explicit parameters (not magical ivars)
- **Tag helpers** for meta tags and interpolated HTML

## Frontend: Stimulus

Small, focused, single-purpose controllers:
- Configured via **Values API** and **Classes API** (no hardcoded strings)
- **Event-based communication** between controllers (`this.dispatch("selected")`)
- **Always clean up** in `disconnect()` (timers, observers, event listeners)
- Use **Targets** over CSS selectors
- Use **`:self` action filter** to scope events
- Extract shared utilities to `helpers/` modules

Read `references/frontend.md` for the full Stimulus controller catalog, CSS architecture, Hotwire patterns, and accessibility guidelines.

## Frontend: CSS

Native CSS only — no Sass, PostCSS, or Tailwind:
- **Cascade layers**: `@layer reset, base, layout, components, utilities`
- **OKLCH color space** for perceptually uniform colors
- **CSS variables** for design tokens and component APIs
- **Native nesting** instead of preprocessors
- **Dark mode** via variable overrides on `html[data-theme="dark"]`
- **Container queries** for component-level responsiveness
- **`:focus-visible`** instead of `:focus` for keyboard-only focus rings
- **Minimal utilities** (~60 classes, not hundreds)
- **Modern features**: `@starting-style`, `color-mix()`, `:has()`, logical properties

## Backend: Background Jobs

Solid Queue (database-backed, no Redis):
- **`enqueue_after_transaction_commit = true`** globally to prevent race conditions
- **Stagger recurring jobs** to prevent resource spikes
- **Shallow jobs** — jobs just call model methods
- **`_later` / `_now` convention** for async/sync method pairs
- **Transient errors**: `retry_on` with `wait: :polynomially_longer`
- **Permanent failures**: swallow gracefully with info-level logging, don't waste queue resources
- **Continuable jobs** (`ActiveJob::Continuable`) for resilient iteration over large batches

## Backend: Caching

- **HTTP caching**: `fresh_when etag: [@cards, Current.user, timezone]`
- **Don't HTTP cache forms** — CSRF tokens get stale
- **Fragment caching**: `cache [card, user_id, timezone]` — include everything that affects output
- **Touch chains**: `belongs_to :card, touch: true` for automatic invalidation
- **Lazy-loaded menus** via Turbo Frames — defer expensive queries until interaction
- **User-specific UI** via Stimulus controllers reading `data-` attributes (not server conditionals)

## Backend: Database

- **UUIDs** (UUIDv7, base36-encoded) as primary keys
- **State as records** over booleans (who, when, metadata)
- **Database-backed infrastructure**: Solid Queue, Solid Cache, Solid Cable
- **Hard deletes** — no soft deletes, use audit logs if needed
- **Counter caches** for denormalized counts
- **DB constraints over AR validations** for data integrity
- **Write-time operations** — pre-compute at save time, not read time
- **`account_id`** on every table for multi-tenancy

## Backend: Authentication

Passwordless magic links (~150 lines, no Devise):
- **Identity** model (global, email-based) — separate from per-account User
- **MagicLink** model (6-digit codes, auto-expiring, rate-limited)
- **Session** model with signed cookies
- **Authentication concern** with DSL: `require_unauthenticated_access`, `allow_unauthenticated_access`
- **Rate limiting** on auth endpoints: `rate_limit to: 10, within: 3.minutes`

Read `references/backend.md` for multi-tenancy, ActionCable, email, webhooks, and other backend patterns.

## Testing

- **Minitest** over RSpec — simpler, less DSL, ships with Rails
- **Fixtures** over factories — faster, deterministic, visible relationships
- **Integration tests** for full request/response cycles
- **System tests** with Capybara for browser testing
- **VCR** for external API recordings — fast, deterministic, works offline
- **`travel_to`** for time-dependent tests
- **`assert_enqueued_with`** for job testing
- **Tests ship with features** in the same commit
- **No test-induced design damage** — never add code just for testability

## Development Philosophy

- **Ship, Validate, Refine** — merge prototype quality code to validate with real usage
- **Fix root causes**, not symptoms
- **Abstractions must earn their keep** — if it doesn't explain or enable 3+ variations, inline it
- **Explicit over clever** — case statements beat metaprogramming for 2-3 cases
- **Fewer lines of code is better** — unless more are clearly justified
- **Concerns for public behavior** — don't extract concerns with only private methods
- **Objects emerge from coupling** — when shared params smell, extract an object
- **Narrow public APIs** — only expose methods that are actually used

Read `references/philosophy.md` for DHH's review patterns and Jorge Manrubia's architecture decisions.

## Reference Files

For detailed patterns beyond this overview, read the appropriate reference file:

- `references/frontend.md` — Stimulus controller catalog, CSS architecture, Hotwire/Turbo patterns, accessibility (ARIA, keyboard nav, screen readers)
- `references/backend.md` — Authentication flow, multi-tenancy middleware, ActionCable, email, webhooks, workflows, filtering, AI/LLM integration, Active Storage, Action Text
- `references/philosophy.md` — DHH's code review patterns (100+ PR reviews), Jorge Manrubia's architecture decisions, Jason Zimdars' design patterns, security checklist

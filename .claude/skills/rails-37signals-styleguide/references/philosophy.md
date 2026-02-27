# Philosophy Reference: DHH Reviews, Architecture Decisions, Design Patterns

## Table of Contents
- [Development Philosophy](#development-philosophy)
- [DHH's Code Review Patterns](#dhhs-code-review-patterns)
- [Jorge Manrubia's Architecture Decisions](#jorge-manrubias-architecture-decisions)
- [Jason Zimdars' Design Patterns](#jason-zimdars-design-patterns)

---

## Development Philosophy

### Ship, Validate, Refine
- Merge "prototype quality" code to validate with real usage before cleanup
- Features evolve through iterations (tenanting took 3 attempts)
- Don't polish prematurely — real-world usage reveals what matters

### Fix Root Causes, Not Symptoms
- **Bad**: Add retry logic for race conditions
- **Good**: Use `enqueue_after_transaction_commit` to prevent the race
- **Bad**: Work around CSRF issues on cached pages
- **Good**: Don't HTTP cache pages with forms

### Vanilla Rails Over Abstractions
- Thin controllers calling rich domain models
- No service objects unless truly justified
- Direct ActiveRecord: `@card.comments.create!(params)`
- When objects exist, they're just POROs: `Signup.new(email:).create_identity`

### When to Extract
- Start in controller, extract when it gets messy
- Don't extract prematurely — wait for pain
- Rule of three: duplicate twice before abstracting

---

## DHH's Code Review Patterns

Extracted from 100+ PR reviews in 37signals' Fizzy codebase.

### Earn Your Abstractions

Every layer of indirection must justify its existence:

> "I find these explicit classes for the notifier rather anemic. And there's not as much future potential for a million more. Think we're better off inlining them."

**The Test**: Ask "Is this abstraction earning its keep?" If you can't point to 3+ variations that need it, inline it.

**Rule**: If a method just wraps another call with no additional logic or explanation, delete it.

### Write-Time vs Read-Time

All manipulation should happen at save time, not presentation time:

```ruby
# Bad — computing at read time (can't paginate)
def thread_entries
  (comments + events).sort_by(&:created_at)
end

# Good — delegated types with single-table query
class Message < ApplicationRecord
  delegated_type :messageable, types: %w[Comment EventSummary]
end
bubble.messages.order(:created_at).limit(20)  # Paginatable!
```

Also: use counter caches, pre-compute sort keys, store summaries at write time.

### Database Over Application Logic

```ruby
# Avoid AR validations for integrity
# validates :code, uniqueness: true

# Prefer DB constraints
add_index :join_codes, :code, unique: true
```

Only validate when you need user-facing error messages for form display.

### Naming Principles

**Positive names**:
```ruby
scope :active, -> { where(popped_at: nil) }    # not :not_popped
scope :visible, -> { where(deleted_at: nil) }   # not :not_deleted
```

**Method names reflect return value**: `create_mentions` not `collect` (which implies returning an array).

**Consistent domain language**: Don't introduce new terms for existing concepts.

### View Patterns

- **Extract logic to helpers, not partials** — if a partial has no HTML, it's a helper or model method
- **Helpers take explicit parameters** — no magical instance variables
- **Double-indent attributes** in tag helpers
- **Use tag helpers** for meta tags with interpolation
- **Turbo Stream canonical style**: `turbo_stream.update [@card, :new_comment], partial: "...", locals: { ... }`

### Stimulus / JavaScript

- **Targets over CSS selectors** — always use `data-*-target`
- **Consider WebSocket updates** — will new elements added via ActionCable be picked up?

### Rails Conventions

- **StringInquirer**: `event.action.completed?` instead of `event.action == "completed"`
- **`after_save_commit`** shorthand instead of `after_commit on: %i[create update]`
- **`pluck`** over `map`: `event.assignees.pluck(:name)` not `.map(&:name)`
- **Delegate for lazy loading**: `delegate :user, to: :session`
- **Touch chains** for cache invalidation: `belongs_to :card, touch: true`
- **Implicit respond_to**: No `respond_to` block when templates exist for both formats
- **Inline Jbuilder partials**: `json.steps @card.steps, partial: "steps/step", as: :step`
- **`head :no_content`** for updates
- **`My::` namespace** for current user resources (`My::IdentitiesController`)

### Migrations

> "Full `db:migrate` is an antipattern. Migrations were only ever meant to be transient."

Using models in migrations is fine: `Notification.update_all(source_type: "Event")`

### Be Explicit Over Clever

When there are only 2-3 cases, explicit `case` statements beat metaprogramming:

> "I think this is too clever. There are only two different types. I would find a way to be explicit about this."

Avoid unnecessary base class extensions — put methods on the specific class.

### Avoid Test-Induced Design Damage

> "Better replace that with a mock or even better just a fixture session. We should never let our desire for ease of testing bleed into the application itself."

### Caching Principles

- Use `touch: true` on associations rather than complex cache key dependencies
- Use `update_all` for bulk cache bumps — no callbacks needed
- Don't make base pages cache-dependent on distant models

### API Design

- **No separate API controllers** — use `respond_to` in the same controller
- **Consistent response codes**: Create → 201, Update → 204, Delete → 204
- **`head :no_content`** for updates that don't need response body

### Authorization

> "If we're allowing unauthenticated access, it should be implied that we're also allowing unauthorized access."

### Key Takeaways (DHH)

1. Abstractions must earn their keep — inline if < 3 variations
2. Write time > Read time — compute at save, not presentation
3. Database over AR — prefer DB constraints
4. Positive names — `active` not `not_deleted`
5. Explicit over clever — case statements for 2-3 variations
6. StringInquirer for predicates — `action.completed?`
7. Touch chains for cache invalidation
8. Helpers take explicit params — no magical ivars
9. Targets over CSS selectors in Stimulus
10. Tests shouldn't shape design — no code just for testability

---

## Jorge Manrubia's Architecture Decisions

### Narrow Public APIs

Only expose methods that are actually used:

```ruby
# Good — narrow public API
class Ai::Quota
  def spend(cost)
  def ensure_not_depleted
  private
    def reset_if_due
    def depleted?
end
```

> "The narrower the public surface of a class the better, since it's easier to grasp its responsibilities at a glance."

### Domain-Driven Naming

Choose names reflecting business reality:
```ruby
quota.spend(cost)           # not increment_usage
quota.ensure_not_depleted   # not ensure_under_limit
quota.depleted?             # not over_limit?
```

### Objects Emerge from Coupling

When parameters get passed through multiple method layers, extract an object:

> "The shared param is often a smell that something is missing."

### Custom Types: Only When Justified

Consider custom Active Model types but weigh the cost. If the conversion only happens in one place, a value object is enough:

```ruby
class Ai::Quota::Money < Data.define(:value)
  MICROCENTS_PER_DOLLAR = 100 * 1_000_000
  def self.wrap(value) = new(convert(value))
  def in_dollars = value.to_d / MICROCENTS_PER_DOLLAR
end
```

### Concerns: Public Behavior Only

Don't extract concerns containing only private methods — inline them in the main class.

### Memoize Hot Paths

```ruby
def as_params
  @as_params ||= {}.tap { |p| p[:indexed_by] = indexed_by; ... }
end
```

> "This method is invoked many times during page rendering and triggers many queries."

### Layer Caching

Cache at multiple levels:
1. **HTTP cache** — `fresh_when` (full response)
2. **Template fragments** — `cache [user, filter, events]` (shared or per-user)
3. **Query cache** — memoization for repeated calls

### Fixed-Point Arithmetic for Money

Store as integers (microcents) to avoid float errors:
```ruby
# SQLite DECIMAL is backed by float:
# (0.1 + 0.1 + 0.1) - 0.3 = 5.55e-17
# Solution: INTEGER with microcents
MICROCENTS_PER_DOLLAR = 100 * 1_000_000
```

### Time-Based Reset Without Cron

Check and reset on use, not scheduled job:
```ruby
def spend(cost)
  transaction { reset_if_due; increment!(:used, cost.in_microcents) }
end
private def reset_if_due = reset if reset_at.before?(Time.current)
```

### VCR for External APIs

```ruby
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<API_KEY>') { credentials.api_key }
end

test "translates filter" do
  VCR.use_cassette("translator/filter") do
    result = Translator.new("cards assigned to jz").translate
    assert_equal "jz", result.context[:assignees].first
  end
end
```

### Key Takeaways (Jorge)

1. Narrow public APIs — only expose what's used
2. Domain names over technical — `depleted?` not `over_limit?`
3. Objects emerge from coupling — shared params → extract object
4. Memoize hot paths — methods called during rendering
5. Layer caching — HTTP, templates, queries
6. Fixed-point for money — integers, not floats
7. Reset on use, not cron — simpler, more reliable
8. VCR for APIs — fast, deterministic tests
9. Custom types only when spread — value object if used in one place
10. Teach through questions — "What do you think of..." not "Change this to..."

---

## Jason Zimdars' Design Patterns

### Perceived Performance > Technical Performance

If it *feels* slow, it's slow — regardless of metrics:
- Lazy-load expensive menus via Turbo Frames
- Show skeleton content during loading
- Auto-submit with debouncing for responsive feel

### Prototype Quality Shipping

"Ship to validate" is a valid quality standard. Don't polish prematurely.

### Production Truth

Real data reveals what local testing can't. Get features in front of users quickly.

### Extend Don't Replace

Branch with parameters, keep old paths working. Don't rewrite — extend existing behavior.

### Visual Coherence

Ship visual redesigns wholesale, not piecemeal. Partial redesigns feel broken.

### Feedback as Vision

Share UX concerns and direction. Let implementers figure out how to achieve it.

### Container Queries for Responsive Cards

Use `@container` for component-level responsiveness rather than viewport breakpoints.

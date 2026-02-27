# Backend Reference: Auth, Multi-Tenancy, Jobs, Database, Features

## Table of Contents
- [Authentication](#authentication)
- [Multi-Tenancy](#multi-tenancy)
- [Database Patterns](#database-patterns)
- [Background Jobs](#background-jobs)
- [Caching](#caching)
- [ActionCable](#actioncable)
- [Email](#email)
- [Webhooks](#webhooks)
- [Filtering](#filtering)
- [AI/LLM Integration](#aillm-integration)
- [Active Storage](#active-storage)
- [Performance](#performance)
- [Security Checklist](#security-checklist)

---

## Authentication

Passwordless magic links (~150 lines, no Devise).

### Models

```ruby
# Identity — global, email-based
class Identity < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :users, dependent: :nullify  # One per account
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(v) { v.strip.downcase.presence }

  def send_magic_link(**attrs)
    magic_links.create!(attrs).tap { |ml| MagicLinkMailer.sign_in_instructions(ml).deliver_later }
  end
end

# MagicLink — 6-digit codes, auto-expiring
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes
  belongs_to :identity
  scope :active, -> { where(expires_at: Time.current...) }
  before_validation :generate_code, :set_expiration, on: :create

  def self.consume(code) = active.find_by(code: Code.sanitize(code))&.consume
  def consume = (destroy; self)
end

# Session
class Session < ApplicationRecord
  belongs_to :identity
end

# User — per-account, linked to identity
class User < ApplicationRecord
  belongs_to :identity
  belongs_to :account
end
```

### Authentication Concern

```ruby
module Authentication
  extend ActiveSupport::Concern
  included do
    before_action :require_account, :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def require_unauthenticated_access(**opts)
      allow_unauthenticated_access(**opts)
      before_action :redirect_authenticated_user, **opts
    end
    def allow_unauthenticated_access(**opts)
      skip_before_action :require_authentication, **opts
      before_action :resume_session, **opts
    end
    def disallow_account_scope(**opts)
      skip_before_action :require_account, **opts
    end
  end

  private
    def require_authentication = resume_session || authenticate_by_bearer_token || request_authentication
    def resume_session = (session = find_session_by_cookie) && set_current_session(session)
    def find_session_by_cookie = Session.find_signed(cookies.signed[:session_token])
    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap { set_current_session(_1) }
    end
    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end
    def terminate_session = (Current.session.destroy; cookies.delete(:session_token))
end
```

### Controllers

```ruby
class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Try again later." }

  def create
    if identity = Identity.find_by_email_address(email_address)
      redirect_to_session_magic_link identity.send_magic_link
    end
  end
  def destroy = (terminate_session; redirect_to_logout_url)
end
```

### Key Principles
- Passwordless is simpler — no password storage, reset flows, or breach liability
- Rate limit aggressively (10 req / 3-15 min)
- Verify email matches — store pending email in session
- Separate identity from user — one person, many accounts
- Session cookie scoped to account path for multi-account support

---

## Multi-Tenancy

Path-based tenancy with shared database.

### Middleware

```ruby
module AccountSlug
  class Extractor
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if request.path_info =~ /\A(\/(\d{7,}))/
        request.script_name = $1
        request.path_info = $'.empty? ? "/" : $'
        env["app.account_id"] = $2
      end
      account = Account.find_by(external_id: env["app.account_id"]) if env["app.account_id"]
      if account
        Current.with_account(account) { @app.call(env) }
      else
        Current.without_account { @app.call(env) }
      end
    end
  end
end
```

### ActiveJob Tenant Preservation

```ruby
module TenantedJob
  extend ActiveSupport::Concern
  prepended do
    attr_reader :account
    self.enqueue_after_transaction_commit = true
  end
  def initialize(...) = (super; @account = Current.account)
  def serialize = super.merge("account" => @account&.to_gid)
  def deserialize(data) = (super; @account = GlobalID::Locator.locate(data["account"]) if data["account"])
  def perform_now = account ? Current.with_account(account) { super } : super
end
```

### Key Rules
- Always scope controller lookups through `Current.account` (defense in depth)
- Scope session cookie path to account: `path: "/#{account.slug}"`
- Recurring jobs must iterate all tenants
- Scope broadcasts: `broadcast_to [Current.account, record]`

---

## Database Patterns

- **UUIDs (UUIDv7)** as primary keys — no enumeration attacks, client-generatable
- **State as records** — `Closure`, `Goldness`, `NotNow` instead of booleans
- **Solid Queue/Cache/Cable** — database-backed, no Redis dependency
- **`account_id`** on every table for multi-tenancy
- **Hard deletes** — no soft deletes, use audit logs for history
- **Counter caches** — `has_many :cards, counter_cache: true`
- **DB constraints over AR validations** — `add_index :codes, :code, unique: true`
- **Strategic indexing** — always index FKs, filter/sort columns, composite for common queries
- **Sharded search** — 16 MySQL shards via CRC32 (over Elasticsearch)

---

## Background Jobs

Solid Queue, database-backed.

### Configuration
- Development: `SOLID_QUEUE_IN_PUMA=1` (run in Puma process)
- Production: match workers to CPU cores, 3 threads for I/O jobs
- **`enqueue_after_transaction_commit = true`** globally

### Patterns
- **Shallow jobs** — just call model methods:
  ```ruby
  class NotifyJob < ApplicationJob
    def perform(notifiable) = notifiable.notify_recipients
  end
  ```
- **`_later` / `_now` convention**:
  ```ruby
  def notify_recipients = Notifier.for(self)&.notify  # public, called by job
  private def notify_recipients_later = NotifyJob.perform_later(self)  # private, called by callback
  ```
- **Stagger recurring jobs** — offset schedules to prevent resource spikes
- **Continuable jobs** — `include ActiveJob::Continuable` for resumable iteration:
  ```ruby
  def perform(event)
    step :dispatch do |step|
      Webhook.active.find_each(start: step.cursor) { |wh| wh.trigger(event); step.advance!(from: wh.id) }
    end
  end
  ```

### Error Handling
- **Transient**: `retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer`
- **Permanent**: `rescue_from Net::SMTPFatalError` — swallow with info-level logging
- **Maintenance**: clean finished jobs hourly, orphaned data daily

---

## Caching

### HTTP Caching
```ruby
def show
  fresh_when etag: [@card, Current.user, timezone_from_cookie]
end
```
Never HTTP cache pages with forms (CSRF tokens get stale).

### Fragment Caching
```erb
<% cache [card, Current.user.id, timezone_from_cookie] do %>
  <%= render "cards/preview", card: card %>
<% end %>
```

### Touch Chains
```ruby
class Comment < ApplicationRecord
  belongs_to :card, touch: true  # Comment change → card cache bust
end
class Card < ApplicationRecord
  belongs_to :board, touch: true  # Card change → board cache bust
end
```

### User-Specific Content in Cached Fragments
Move personalization to client-side Stimulus:
```erb
<% cache card do %>
  <div data-creator-id="<%= card.creator_id %>" data-controller="ownership">
    <button data-ownership-target="ownerOnly" class="hidden">Delete</button>
  </div>
<% end %>
```

### Lazy-Loaded Content
Extract expensive queries to Turbo Frames loaded on interaction:
```erb
<%= turbo_frame_tag "my_menu", src: my_menu_path, loading: :lazy %>
```

---

## ActionCable

- **Solid Cable** (database-backed, no Redis)
- **Multi-tenant scoping**: `broadcast_to [Current.account, card]`
- **`broadcasts_refreshes`** for automatic Turbo updates
- **Disconnect deactivated users**: `ActionCable.server.remote_connections.where(current_user: self).disconnect`

---

## Email

- Multi-tenant mailers with Current context
- Timezone handling in mailer views
- Magic link code in subject line (users see in notifications)
- SMTP error handling:
  - Transient (4xx): retry with `polynomially_longer`
  - Permanent (5xx): swallow with info-level logging
- Rate limiting on email-sending endpoints

---

## Webhooks

- **SSRF protection**: resolve DNS once, pin IP; block private networks (127/10/172.16/192.168/169.254)
- **Validate at creation AND request time**
- **State machines** for webhook lifecycle
- **Delinquency tracking** for failing endpoints
- **Continuable jobs** for dispatch across many webhooks

---

## Filtering

- **Filter objects** that build scoped queries
- **URL-based state** for shareable filter links
- **Persisted filters** — users can save and name filters
- **FilterScoped concern** for controllers:
  ```ruby
  module FilterScoped
    included do
      before_action :set_filter, :set_user_filtering
    end
    def set_filter
      @filter = params[:filter_id].present? ?
        Current.user.filters.find(params[:filter_id]) :
        Current.user.filters.from_params(filter_params)
    end
  end
  ```

---

## AI/LLM Integration

- **Command pattern** for AI operations
- **Cost tracking** with Money value object (fixed-point in microcents)
- **Quota model** with spend/reset lifecycle
- **Token limit guards**: truncate with Tiktoken before sending
- **VCR cassettes** for deterministic AI tests

---

## Active Storage

- Use `preprocessed: true` for variants (lazy generation fails on read replicas)
- Extend signed URL expiry to 48h (Cloudflare buffering can exceed 5min default)
- Skip previews above size threshold (16MB) to avoid timeouts
- Redirect to blob URL instead of streaming through Rails for avatars

---

## Performance

- **N+1 prevention**: `scope :preloaded, -> { includes(:column, :tags, board: [:columns]) }`
- **`prosopite` gem** for N+1 detection
- **Counter caches** for fast reads
- **Batch SQL** (JOINs) over `find_each` loops
- **Memoize hot paths**: `@result ||= expensive_computation`
- **Pagination**: 25-50 items, "Load more" buttons
- **Puma tuning**: `workers Concurrent.physical_processor_count; threads 1, 1`
- **`Process.warmup`** in `before_fork` for GC/compact/malloc_trim

---

## Security Checklist

### XSS
- Always `h(user_input)` before `.html_safe`
- Escape in helpers, not views

### CSRF
- Don't HTTP cache pages with forms
- Use `Sec-Fetch-Site` header as additional check
- Add `Sec-Fetch-Site` to Vary header

### SSRF (webhooks, user URLs)
- DNS rebinding protection (resolve once, pin IP)
- Block private networks (loopback, private, link-local, IPv4-mapped IPv6)
- Validate at creation AND request time

### Rate Limiting
```ruby
rate_limit to: 10, within: 3.minutes, only: :create
```
Apply to: auth endpoints, email sending, external API calls, resource creation.

### Authorization
- Model predicates: `card.editable_by?(user)`
- Controller checks: `before_action :ensure_can_administer`
- Simple concern with `ensure_can_administer`, `ensure_is_staff_member`

### Content Security Policy
```ruby
config.content_security_policy do |policy|
  policy.script_src :self
  policy.style_src :self, :unsafe_inline
  policy.base_uri :none
  policy.form_action :self
  policy.frame_ancestors :self
end
```

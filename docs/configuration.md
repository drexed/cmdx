# Configuration

This page is about **telling CMDx how to behave**: loggers, telemetry, middleware, custom coercers — the whole backstage crew.

There are two “floors” to the building:

1. **Global** — `CMDx.configure { … }` sets defaults for the whole process.
2. **Per task class** — `settings`, `register`, `retry_on`, and friends tweak one family of tasks.

If that sounds like inheritance, you’re on the right track — just read the warning below so tests don’t surprise you.

## Configuration hierarchy

CMDx keeps **global** defaults and lets each **task class** override or extend them (loggers, tags, strict context, etc.).

!!! warning "Order matters (especially in tests)"

    Class-level registries **copy lazily** from the parent the first time you touch them. Rule of thumb: run `CMDx.configure` **before** tasks start using registries, or call `CMDx.reset_configuration!` in test setup so stale copies don’t stick around.

## Global configuration

### Defaults

| Setting | Default | In plain English |
|---------|---------|------------------|
| `logger` | `Logger.new($stdout, progname: "cmdx", formatter: Line.new, level: INFO)` | Where INFO-ish lines go |
| `log_level` | `nil` | Optional override; `nil` means “trust the logger’s level” |
| `log_formatter` | `nil` | Optional override; `nil` means “trust the logger’s formatter” |
| `log_exclusions` | `[]` | Keys to strip from the **log line** of `Result#to_h` (e.g. hide fat `:context`) |
| `default_locale` | `"en"` | Fallback language for built-in messages when I18n isn’t in play |
| `backtrace_cleaner` | `nil` | Optional `Fault` backtrace scrubber |
| `strict_context` | `false` | Typo on `context.foo` → `NoMethodError` instead of `nil` |
| `correlation_id` | `nil` | Callable → one id per root run, exposed as `xid` |
| `middlewares` | `Middlewares.new` (empty) | Global middleware stack |
| `callbacks` | `Callbacks.new` (empty) | Global callbacks |
| `coercions` | `Coercions.new` (13 built-ins) | Input coercers |
| `validators` | `Validators.new` (7 built-ins) | Input validators |
| `executors` | `Executors.new` (`:threads`, `:fibers`) | Parallel workflow backends |
| `mergers` | `Mergers.new` (`:last_write_wins`, `:deep_merge`, `:no_merge`) | How parallel branches merge into context |
| `retriers` | `Retriers.new` (7 built-ins) | Named retry / jitter strategies |
| `deprecators` | `Deprecators.new` (`:log`, `:warn`, `:error`) | How deprecations surface |
| `telemetry` | `Telemetry.new` (empty) | Pub/sub bus for runtime events |

### Default locale

When the `I18n` gem **isn’t** loaded, CMDx uses `default_locale` for its own strings (validation errors, coercion errors, …). Full list: [Internationalization](internationalization.md).

```ruby
CMDx.configure do |config|
  config.default_locale = "es"
end
```

!!! note

    If `I18n` **is** loaded, CMDx delegates translations to it and follows `I18n.locale` — `default_locale` sits this one out.

### Backtrace cleaner

Faults can dump huge stack traces. A **backtrace cleaner** is any callable: `Array<String> in → Array<String> out`.

```ruby
CMDx.configure do |config|
  config.backtrace_cleaner = ->(bt) { bt.reject { |l| l.include?("/gems/") } }

  # Rails:
  config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
end
```

!!! note

    In Rails, the Railtie wires a sensible default so you often don’t touch this.

### Strict context

With `strict_context: true`, a bad dynamic read like `context.typo` raises **`NoMethodError`** instead of quietly returning `nil`. Hash-style access (`[]`, `fetch`, `dig`, …) stays forgiving. More examples: [Context - Strict Mode](basics/context.md#strict-mode).

```ruby
CMDx.configure do |config|
  config.strict_context = true
end
```

Per-class override: `settings(strict_context: true)`.

### Correlation ID (`xid`)

Want every task in a chain to share one **request id** (or trace id) for logs and metrics? Set `correlation_id` to a callable. CMDx calls it **once** when the root chain starts; every `Result` and telemetry event in that run gets the same `xid`.

```ruby
CMDx.configure do |config|
  config.correlation_id = -> { Current.request_id }
end

result = ProcessOrder.execute(order_id: 42)
result.xid                            #=> "abc-123-..."
result.chain.map(&:xid).uniq          #=> ["abc-123-..."]  # whole chain matches
```

You can also set `settings(correlation_id: -> { … })` on a base task class if one subtree needs different rules. `nil` from the callable → `xid` stays `nil`. If the callable blows up, you’ll see it — that’s on purpose so misconfigurations don’t hide.

!!! note

    Only the **root** run resolves the id; nested tasks reuse the chain’s value so `xid` stays stable for the whole execution.

### Logging

```ruby
CMDx.configure do |config|
  config.logger         = Logger.new($stdout, progname: "cmdx")
  config.log_level      = Logger::DEBUG
  config.log_formatter  = CMDx::LogFormatters::JSON.new
  config.log_exclusions = [:context]
end
```

Built-in formatters live under `CMDx::LogFormatters`: `Line` (default), `JSON`, `KeyValue`, `Logstash`, `Raw`. See [Logging](logging.md) for fields and samples.

`log_exclusions` only affects the **log line** built from `Result#to_h` — handy to drop giant `:context` blobs. The in-memory `Result` and telemetry payloads stay full.

### Middlewares

Middleware wraps the **entire** task lifecycle. Signature: `call(task) { … }` — you must `yield` (or `next_link.call` from a Proc) or the task never runs.

```ruby
CMDx.configure do |config|
  # Class with #call(task)
  config.middlewares.register CustomMiddleware

  # Instance with captured options
  config.middlewares.register CustomMiddleware.new(threshold: 1000)

  # Proc / Lambda — capture &next_link to forward the chain
  config.middlewares.register(proc do |task, &next_link|
    locale = Current.user.locale || I18n.default_locale
    I18n.with_locale(locale) do
      task.metadata[:locale] = locale
      next_link.call
    end
  end)

  # Pin order: 0 = outermost
  config.middlewares.register MyOuterMiddleware, at: 0

  config.middlewares.deregister CustomMiddleware
end
```

!!! danger "Caution"

    If middleware never calls the next link, CMDx raises `CMDx::MiddlewareError` — so you don’t silently “skip” tasks.

More patterns: [Middlewares](middlewares.md).

### Callbacks

Global callbacks use the same **event names** as on a class. Quick map:

| Event | Roughly when |
|-------|----------------|
| `:before_execution` | Before `work` |
| `:before_validation` | After `:before_execution`, before inputs are resolved |
| `:around_execution` | Wraps `work` and `rollback` — must run continuation once |
| `:after_execution` | After `work` / `rollback` |
| `:on_complete` | State is `"complete"` (happy path finished) |
| `:on_interrupted` | State is `"interrupted"` (skip or fail) |
| `:on_success` | Status is `"success"` |
| `:on_skipped` | Status is `"skipped"` |
| `:on_failed` | Status is `"failed"` |
| `:on_ok` | Signal says “not failed” (success or skip) |
| `:on_ko` | Signal says “not pure success” (skip or fail) |

```ruby
CMDx.configure do |config|
  # Symbol → `task.send(:method)`
  config.callbacks.register :before_execution, :initialize_session

  # Class / instance with #call(task)
  config.callbacks.register :on_success, LogUserActivity

  # Proc — runs in the task’s context; still no `result` yet; use `:task_executed` for duration, etc.
  config.callbacks.register(:on_complete, proc do |task|
    StatsD.increment("task.completed", tags: ["task:#{task.class}"])
  end)

  config.callbacks.deregister :on_success                  # all :on_success hooks
  config.callbacks.deregister :on_success, LogUserActivity # just this match (`==`)
end
```

`deregister(event)` alone clears **everything** for that event; add a second arg to remove one entry. Unknown event → `ArgumentError`. No matching callable → no-op.

Class-level recipes: [Callbacks](callbacks.md).

### Telemetry

Simple mental model: **publish events, subscribe with lambdas**. Each event delivers a `Telemetry::Event` (`cid`, `xid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`).

| Event | Payload (extra) |
|-------|-----------------|
| `:task_started` | empty |
| `:task_deprecated` | empty |
| `:task_retried` | `{ attempt: Integer }` |
| `:task_rolled_back` | empty |
| `:task_executed` | `{ result: Result }` |

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed, ->(event) {
    StatsD.timing("cmdx.task", event.payload[:result].duration, tags: [
      "class:#{event.task}",
      "status:#{event.payload[:result].status}"
    ])
  })

  config.telemetry.subscribe(:task_retried, ->(event) {
    Rails.logger.warn("[cmdx] retry ##{event.payload[:attempt]} for #{event.task}")
  })

  config.telemetry.unsubscribe(:task_executed, my_subscriber)
end
```

!!! tip

    Events are only emitted if **someone subscribed** — so unused event types cost nothing.

### Coercions

A coercion is `(value, **options) → coerced value` or `CMDx::Coercions::Failure.new("message")` on failure.

```ruby
CMDx.configure do |config|
  config.coercions.register :currency, CurrencyCoercion

  config.coercions.register(:tag_list, proc do |value, **opts|
    delimiter = opts[:delimiter] || ","
    max_tags  = opts[:max_tags] || 50
    value.to_s.split(delimiter).map(&:strip).reject(&:empty?).first(max_tags)
  end)

  config.coercions.deregister :currency
end
```

Usage from inputs: [Inputs - Coercions](inputs/coercions.md).

### Validators

A validator is `(value, options)` with `options` as a positional Hash. Return `CMDx::Validators::Failure.new(message)` to fail; anything else (even `nil`) counts as pass.

```ruby
CMDx.configure do |config|
  config.validators.register :uuid, UuidValidator

  config.validators.register(:access_token, proc do |value, options|
    prefix = options[:prefix] || "tok_"
    min    = options[:min_length] || 40

    unless value.is_a?(String) && value.start_with?(prefix) && value.length >= min
      CMDx::Validators::Failure.new("invalid access token")
    end
  end)

  config.validators.deregister :uuid
end
```

More: [Inputs - Validations](inputs/validations.md).

### Executors

Executors power **parallel** workflow groups. Contract: `call(jobs:, concurrency:, on_job:)` — call `on_job.call(job)` for each job, wait until all finish. Built-ins: `:threads` (default), `:fibers`.

```ruby
CMDx.configure do |config|
  config.executors.register :ractor, RactorExecutor

  config.executors.register(:inline, proc do |jobs:, concurrency:, on_job:|
    jobs.each { |job| on_job.call(job) }
  end)

  config.executors.deregister :fibers
end
```

See [Workflows - Parallel Groups](workflows.md#parallel-execution).

### Mergers

After parallel branches succeed, a **merger** folds their outputs into the workflow context: `call(workflow_context, result)`. Built-ins: `:last_write_wins` (default), `:deep_merge`, `:no_merge`.

```ruby
CMDx.configure do |config|
  config.mergers.register(:whitelist, proc do |ctx, result|
    result.context.to_h.slice(:user_id, :tenant_id).each { |k, v| ctx[k] = v }
  end)

  config.mergers.deregister :no_merge
end
```

Same workflow doc: [Workflows - Parallel Groups](workflows.md#parallel-execution).

## Class-level configuration

### Settings

`settings` is the small set of per-class knobs that mirror globals: logger-ish things, tags, `strict_context`, `correlation_id`, etc.

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    logger: CustomLogger.new($stdout),
    log_formatter: CMDx::LogFormatters::JSON.new,
    log_level: Logger::DEBUG,
    log_exclusions: [:context, :metadata],
    backtrace_cleaner: ->(bt) { bt.first(8) },
    tags: ["billing", "financial"],
    strict_context: true
  )

  def work
    # ...
  end
end
```

Anything you omit falls back to `CMDx.configuration`. Subclasses inherit and merge — later `settings` calls layer on top (last merge wins per key).

```ruby
class BaseTask < CMDx::Task
  settings(tags: ["api"])
end

class ChildTask < BaseTask
  settings(tags: ["billing"], log_level: Logger::DEBUG)
  # tags => ["billing"]  (child overrides)
end
```

!!! note

    `settings` only stores logging / tracing-ish keys (`:logger`, `:log_formatter`, `:log_level`, `:log_exclusions`, `:backtrace_cleaner`, `:tags`, `:strict_context`, `:correlation_id`). Retries and deprecations use their own DSLs.

### Retry

`retry_on` stacks across inheritance — list the exceptions, cap attempts, pick jitter. Full menu of options: [Retries](retries.md).

```ruby
class FetchInvoice < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout,
    limit: 3,
    delay: 0.5,
    max_delay: 5.0,
    jitter: :exponential   # :exponential, :half_random, :full_random, :bounded_random, :linear, :fibonacci, :decorrelated_jitter

  retry_on External::ApiError, limit: 5 do |attempt, delay|
    delay * (attempt + 1)  # custom backoff
  end
end
```

!!! note

    If you pass both `jitter:` and a custom block, **`jitter:` wins** — the block is ignored. Pick one story.

### Deprecation

Handled with the class-level `deprecation` DSL (not `settings`). Full guide: [Deprecation](deprecation.md).

```ruby
class LegacyTask < CMDx::Task
  deprecation :error, if: -> { Rails.env.production? }
end
```

### Registrations (`register` / `deregister`)

Attach middleware, callbacks, coercions, validators — or inputs/outputs — to **one** task class.

```ruby
class SendCampaignEmail < CMDx::Task
  register :middleware, AuditTrailMiddleware
  deregister :middleware, GlobalLoggingMiddleware

  before_execution :find_campaign
  on_complete proc { |task| Analytics.track("email_sent", task.context.recipient) }
  register :callback, :on_failed, :send_alert

  register :coercion, :currency, CurrencyCoercion
  register :validator, :uuid, UuidValidator

  register :input, :recipient_id, coerce: :integer, presence: true
  register :output, :delivered_at
end
```

For day-to-day input/output definitions, the `required` / `optional` / `output` helpers are usually nicer than raw `register :input` — see [Inputs - Definitions](inputs/definitions.md) and [Outputs](outputs.md).

!!! note

    `deregister` mirrors `register`. Callbacks: `deregister :callback, event[, callable]`. Middlewares: `deregister :middleware, thing` or `at:` index.

## Reading and resetting config

### Access

```ruby
CMDx.configuration.logger
CMDx.configuration.middlewares.size
CMDx.configuration.coercions.registry

class ProcessUpload < CMDx::Task
  settings(tags: ["files"])

  def work
    self.class.settings.tags        #=> ["files"]
    self.class.settings.logger      #=> falls back to global
    self.class.middlewares.size
  end
end
```

### Reset

`CMDx.reset_configuration!` swaps in a fresh global config and clears cached registries on `Task` so the next access rebuilds from scratch — **super common in specs**.

```ruby
CMDx.reset_configuration!

RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

!!! warning

    Reset clears caches on `Task`, but subclasses that already copied registries might still hold old data. In tests, anonymous task classes or `stub_const` per example keep life simple.

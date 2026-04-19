# Configuration

Configure CMDx to register components, control logging, and customize framework behavior. Configuration lives at two levels: global defaults and per-class overrides.

## Configuration Hierarchy

CMDx uses a two-tier configuration system:

1. **Global Configuration** — Framework-wide defaults via `CMDx.configure`
2. **Class-level overrides** — On the task class via `settings`, `register`, `deregister`, `retry_on`, `deprecation`

!!! warning "Important"

    Class-level registries (`middlewares`, `callbacks`, `coercions`, `validators`, `telemetry`) are **lazily duplicated** from the parent class (or from the global configuration at the top of the hierarchy) on first access. Configure globals before any task first touches a registry, or call `CMDx.reset_configuration!` in test setup to invalidate the cached copies on `Task`.

## Global Configuration

### Default Values

| Setting | Default | Description |
|---------|---------|-------------|
| `logger` | `Logger.new($stdout, progname: "cmdx", formatter: Line.new, level: INFO)` | Logger instance |
| `log_level` | `Logger::INFO` | Logger severity |
| `log_formatter` | `CMDx::LogFormatters::Line.new` | Formatter instance |
| `default_locale` | `"en"` | Locale for built-in translation fallbacks |
| `backtrace_cleaner` | `nil` | Callable to clean fault backtraces |
| `middlewares` | `Middlewares.new` (empty) | Middleware registry |
| `callbacks` | `Callbacks.new` (empty) | Callback registry |
| `coercions` | `Coercions.new` (13 built-ins) | Coercion registry |
| `validators` | `Validators.new` (7 built-ins) | Validator registry |
| `telemetry` | `Telemetry.new` (empty) | Telemetry pub/sub |

### Default Locale

Set the locale used for built-in translation fallbacks when the `I18n` gem isn't loaded. See [Internationalization](internationalization.md) for the full locale list.

```ruby
CMDx.configure do |config|
  config.default_locale = "es"
end
```

!!! note

    When `I18n` is loaded, CMDx delegates to `I18n.translate` and `default_locale` is unused — locale comes from `I18n.locale`. Without `I18n`, all built-in messages (validation errors, coercion errors, etc.) resolve from this setting.

### Backtrace Cleaner

Trim noise from `Fault` backtraces with any callable that takes `Array<String>` and returns a cleaned array.

```ruby
CMDx.configure do |config|
  config.backtrace_cleaner = ->(bt) { bt.reject { |l| l.include?("/gems/") } }

  # Rails:
  config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
end
```

!!! note

    Rails apps wire this automatically via `CMDx::Railtie`.

### Logging

```ruby
CMDx.configure do |config|
  config.logger        = Logger.new($stdout, progname: "cmdx")
  config.log_level     = Logger::DEBUG
  config.log_formatter = CMDx::LogFormatters::JSON.new
end
```

Built-in formatters live under `CMDx::LogFormatters`: `Line` (default), `JSON`, `KeyValue`, `Logstash`, `Raw`. See [Logging](logging.md) for the emitted fields and sample output.

### Middlewares

Middlewares wrap the entire task lifecycle. The signature is `call(task) { ... }` — call `yield` (or `next_link.call` from a Proc) to invoke the next link.

```ruby
CMDx.configure do |config|
  # Class with #call(task)
  config.middlewares.register CustomMiddleware

  # Instance
  config.middlewares.register CustomMiddleware.new(threshold: 1000)

  # Proc / Lambda — must declare &next_link to pass the block
  config.middlewares.register(proc do |task, &next_link|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    next_link.call
  ensure
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    Rails.logger.debug { "#{task.class} ran in #{(duration * 1000).round(2)}ms" }
  end)

  # Insert at a specific position
  config.middlewares.register MyOuterMiddleware, at: 0

  # Remove
  config.middlewares.deregister CustomMiddleware
end
```

!!! danger "Caution"

    A middleware that forgets to yield raises `CMDx::MiddlewareError` — the task body is never invoked, so silent skips are caught immediately.

See the [Middlewares](middlewares.md) docs for class-level configuration.

### Callbacks

Callbacks fire at specific lifecycle points. Valid events:

| Event | When |
|-------|------|
| `:before_execution` | First lifecycle step inside `measure_duration` |
| `:before_validation` | Right after `:before_execution`, before input resolution |
| `:on_complete` | When `state == "complete"` (success path) |
| `:on_interrupted` | When `state == "interrupted"` (skip or fail) |
| `:on_success` | When `status == "success"` |
| `:on_skipped` | When `status == "skipped"` |
| `:on_failed` | When `status == "failed"` |
| `:on_ok` | Success or skipped (`signal.ok?`) |
| `:on_ko` | Skipped or failed (`signal.ko?`) |

```ruby
CMDx.configure do |config|
  # Symbol — dispatched as task.send(:method)
  config.callbacks.register :before_execution, :initialize_session

  # Class / instance with #call(task)
  config.callbacks.register :on_success, LogUserActivity

  # Proc / Lambda — instance_exec'd on the task; receives task as block arg.
  # The Result isn't built yet during callbacks; subscribe to Telemetry's
  # :task_executed event when you need result data like duration.
  config.callbacks.register(:on_complete, proc do |task|
    StatsD.increment("task.completed", tags: ["task:#{task.class}"])
  end)

  # Remove every callback for an event
  config.callbacks.deregister :on_success

  # Or remove a specific entry — match by `==` (Procs/Lambdas by identity)
  config.callbacks.deregister :on_success, LogUserActivity
end
```

!!! note

    `deregister(event)` drops every callback for that event; pass a second argument to remove only matching entries (matched by `==`). Unknown events raise `ArgumentError`; unmatched callables are a silent no-op.

See [Callbacks](callbacks.md) for class-level usage.

### Telemetry

Pub/sub for runtime lifecycle events. Subscribers receive a `Telemetry::Event` data object with `chain_id`, `chain_root`, `task_type`, `task_class`, `task_id`, `name`, `payload`, and `timestamp`.

| Event | Payload |
|-------|---------|
| `:task_started` | empty |
| `:task_deprecated` | empty |
| `:task_retried` | `{ attempt: Integer }` |
| `:task_rolled_back` | empty |
| `:task_executed` | `{ result: Result }` |

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed, ->(event) {
    StatsD.timing("cmdx.task", event.payload[:result].duration, tags: [
      "class:#{event.task_class}",
      "status:#{event.payload[:result].status}"
    ])
  })

  config.telemetry.subscribe(:task_retried, ->(event) {
    Rails.logger.warn("[cmdx] retry ##{event.payload[:attempt]} for #{event.task_class}")
  })

  config.telemetry.unsubscribe(:task_executed, my_subscriber)
end
```

!!! tip

    Runtime emits events **only** when subscribers exist for them, so unused events have zero overhead.

### Coercions

Custom coercions are callables receiving `(value, **options)` and returning the coerced value or `CMDx::Coercions::Failure.new(message)` on failure.

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

See [Inputs - Coercions](inputs/coercions.md) for usage.

### Validators

Custom validators are callables receiving `(value, options)` (options is a positional hash). Return `CMDx::Validators::Failure.new(message)` to mark the value invalid; any other return value (including `nil`) is treated as success.

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

See [Inputs - Validations](inputs/validations.md) for usage.

## Class-Level Configuration

### Settings

`Settings` exposes a small set of per-class overrides for logger and tagging:

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    logger: CustomLogger.new($stdout),
    log_formatter: CMDx::LogFormatters::JSON.new,
    log_level: Logger::DEBUG,
    backtrace_cleaner: ->(bt) { bt.first(8) },
    tags: ["billing", "financial"]
  )

  def work
    # ...
  end
end
```

Every getter falls back to the global configuration when an option isn't set. Subclasses inherit and may layer on top — multiple `settings(...)` calls compose (each merges on top of the previous).

```ruby
class BaseTask < CMDx::Task
  settings(tags: ["api"])
end

class ChildTask < BaseTask
  settings(tags: ["billing"], log_level: Logger::DEBUG)
  # tags = ["billing"] (child wins; settings.build does Hash#merge)
end
```

!!! note

    `Settings` only stores `:logger`, `:log_formatter`, `:log_level`, `:backtrace_cleaner`, and `:tags`. Other class-level config uses dedicated DSL (`retry_on`, `deprecation`, `register`, `before_execution`, …).

### Retry

Configure exception-based retries with `retry_on`. Accumulates across inheritance.

```ruby
class FetchInvoice < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout,
    limit: 3,
    delay: 0.5,
    max_delay: 5.0,
    jitter: :exponential   # :exponential, :half_random, :full_random, :bounded_random

  retry_on External::ApiError, limit: 5 do |attempt, delay|
    delay * (attempt + 1)  # custom jitter block
  end
end
```

!!! note

    `jitter:` takes precedence over a custom block — pass one or the other, not both, or the block is silently ignored.

### Deprecation

See [Deprecation](deprecation.md). Declared via the class-level `deprecation` DSL — **not** via `settings`.

```ruby
class LegacyTask < CMDx::Task
  deprecation :error, if: -> { Rails.env.production? }
end
```

### Registrations

Register or deregister middlewares, callbacks, coercions, and validators on a specific task class.

```ruby
class SendCampaignEmail < CMDx::Task
  # Middlewares
  register :middleware, AuditTrailMiddleware
  deregister :middleware, GlobalLoggingMiddleware

  # Callbacks (use the dedicated DSL OR register :callback explicitly)
  before_execution :find_campaign
  on_complete proc { |task| Analytics.track("email_sent", task.context.recipient) }
  register :callback, :on_failed, :send_alert

  # Coercions
  register :coercion, :currency, CurrencyCoercion

  # Validators
  register :validator, :uuid, UuidValidator

  # Inputs / outputs (per-class schemas)
  register :input, :recipient_id, coerce: :integer, presence: true
  register :output, :delivered_at, presence: true
end
```

See [Inputs - Definitions](inputs/definitions.md) and [Outputs](outputs.md) for the full schema DSL — the dedicated `required` / `optional` / `output` helpers are usually preferred over `register :input` / `register :output`.

!!! note

    `deregister` mirrors `register`'s arity per registry. For callbacks: `deregister :callback, event` clears every entry for that event, or pass a third arg (`deregister :callback, event, callable`) to drop only matching entries (matched by `==`). For middlewares: `deregister :middleware, callable_or_class` (or `at:` index) matches by reference.

## Configuration Management

### Access

```ruby
# Global
CMDx.configuration.logger              #=> <Logger instance>
CMDx.configuration.middlewares.size    #=> 0
CMDx.configuration.coercions.registry  #=> { array: ..., big_decimal: ..., ... }

# Class-level
class ProcessUpload < CMDx::Task
  settings(tags: ["files"])

  def work
    self.class.settings.tags        #=> ["files"]
    self.class.settings.logger      #=> falls back to CMDx.configuration.logger
    self.class.middlewares.size     #=> inherited count
  end
end
```

### Resetting

`CMDx.reset_configuration!` replaces the global config with a fresh instance and invalidates the cached registries on `Task` so subclasses rebuild from the new config on next access.

```ruby
CMDx.reset_configuration!

# Test setup (RSpec)
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

!!! warning "Important"

    `reset_configuration!` clears `@middlewares`, `@callbacks`, `@coercions`, `@validators`, and `@telemetry` on `Task` only — subclasses that already cached their own copy keep them. In tests, prefer letting each example use freshly defined task classes (e.g. via `stub_const` or anonymous classes).

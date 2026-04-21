# Configuration Reference

Docs: [docs/configuration.md](../../docs/configuration.md), [docs/callbacks.md](../../docs/callbacks.md), [docs/middlewares.md](../../docs/middlewares.md), [docs/retries.md](../../docs/retries.md), [docs/deprecation.md](../../docs/deprecation.md).

Configuration lives at three levels:

1. **Global** — `CMDx.configure`, applies to every task unless overridden.
2. **Per-task (`settings`)** — narrow override bag: loggers, formatters, tags, backtrace cleaner.
3. **Per-task DSL** — everything else (retries, deprecation, middleware, callbacks, coercions, validators, inputs, outputs).

Subclasses **inherit** all three levels. Registries are duped lazily the first time a subclass touches them.

## Global

```ruby
CMDx.configure do |config|
  config.default_locale    = "en"
  config.backtrace_cleaner = ->(frames) { Rails.backtrace_cleaner.clean(frames) }
  config.logger            = Logger.new($stdout)
  config.log_level         = Logger::INFO
  config.log_formatter     = CMDx::LogFormatters::JSON.new

  config.middlewares.register MyGlobalMiddleware
  config.callbacks.register   :on_failed, ErrorTracker
  config.coercions.register   :money, MoneyCoercion
  config.validators.register  :api_key, ApiKeyValidator
  config.telemetry.subscribe(:task_executed) { |event| emit(event) }
end
```

All real `Configuration` attributes:

| Attribute | Default |
|-----------|---------|
| `middlewares` | `Middlewares.new` |
| `callbacks` | `Callbacks.new` |
| `coercions` | `Coercions.new` |
| `validators` | `Validators.new` |
| `telemetry` | `Telemetry.new` |
| `default_locale` | `"en"` |
| `backtrace_cleaner` | `nil` |
| `logger` | `Logger.new($stdout)` |
| `log_level` | `Logger::INFO` |
| `log_formatter` | `CMDx::LogFormatters::Line.new` |

`CMDx.reset_configuration!` replaces the configuration with a fresh instance and clears `Task`'s cached registry ivars so new lookups pick up the new config. Intended for test setup/teardown; it does **not** recurse into subclasses.

## Per-task `settings`

`settings(...)` stores **only** the following options — everything else is ignored. Every getter falls back to the global configuration.

| Option | Purpose |
|--------|---------|
| `:logger` | Per-task Logger. |
| `:log_formatter` | Per-task formatter. |
| `:log_level` | Per-task severity. |
| `:backtrace_cleaner` | `#call(frames)`-able for `Fault` backtraces. |
| `:tags` | Array of `Symbol`/`String`, exposed on `result.to_h[:tags]`. |

```ruby
class MyTask < CMDx::Task
  settings(
    tags:              ["critical", :billing],
    log_level:         Logger::DEBUG,
    backtrace_cleaner: ->(f) { f.reject { |l| l.include?("gems/") } }
  )
end
```

Calling `settings(...)` with new options merges onto the inherited (or default) Settings and replaces the cache. Calling `settings` with no args returns the current Settings.

## Retries

Per-class DSL (not a `settings` option):

```ruby
class Fetch < CMDx::Task
  retry_on Net::OpenTimeout, Net::ReadTimeout,
    limit:    3,
    delay:    0.5,
    max_delay: 5.0,
    jitter:   :exponential
end
```

Options:

| Option | Default | Notes |
|--------|---------|-------|
| `:limit` | `3` | Max retry attempts (so `limit + 1` total tries). |
| `:delay` | `0.5` | Base seconds between attempts; `0` disables sleep. |
| `:max_delay` | — | Upper clamp for computed delay. |
| `:jitter` | — | Symbol (`:exponential`, `:half_random`, `:full_random`, `:bounded_random`), Symbol method on the task, Proc (`instance_exec(attempt, delay)`), or any `#call(attempt, delay)`-able. A block passed to `retry_on` is equivalent to `jitter:`. |

Multiple `retry_on` calls **merge**: exceptions accumulate, later options override earlier ones. Subclasses inherit and extend the parent's `Retry`.

```ruby
retry_on Api::Throttled, limit: 5 do |attempt, delay|
  delay * (attempt + 1)
end
```

Only the `work` block is wrapped. Inputs, outputs, callbacks, and middleware run once. `task.errors` persists across attempts; clear it at the start of `work` if you re-populate per attempt.

Introspect: `result.retries`, `result.retried?`.

## Deprecation

Class-level DSL:

```ruby
class LegacyTask < CMDx::Task
  deprecation :log                                # logger.warn
  deprecation :warn                               # Kernel.warn
  deprecation :error                              # raises CMDx::DeprecationError
  deprecation :custom_deprecation_handler         # task method
  deprecation -> { MyTracker.record(self.class) } # Proc (instance_exec on task)
  deprecation MyDeprecationHandler                # #call(task)
  deprecation :log, if: -> { Rails.env.production? }
end
```

Fires **before** `run_lifecycle`. `:error` aborts with `CMDx::DeprecationError` (subclass of `CMDx::Error`) — no result is produced. `:if`/`:unless` gates take the task as argument.

## Registrations

`register` and `deregister` dispatch to the six sub-registries:

| Type | Registry | Notes |
|------|----------|-------|
| `:middleware` | `middlewares` | Accepts `#call(task)`-able or block. Optional `at:` index. |
| `:callback` | `callbacks` | `register :callback, event, callable` or `dsl_method(callable, &)`. |
| `:coercion` | `coercions` | `register :coercion, :name, callable`. |
| `:validator` | `validators` | `register :validator, :name, callable`. |
| `:input` | `inputs` | Typically use `input`/`inputs`/`required`/`optional`. |
| `:output` | `outputs` | Typically use `output`/`outputs`. |

```ruby
class MyTask < CMDx::Task
  register   :middleware, TimingMiddleware.new
  register   :middleware, ->(task, &next_link) { next_link.call }, at: 0
  register   :callback,   :on_failed, ErrorTracker
  register   :coercion,   :money,     MoneyCoercion
  register   :validator,  :api_key,   ApiKeyValidator

  deregister :middleware, TimingMiddleware
  deregister :middleware, at: -1
  deregister :callback,   :on_failed                # drops all for event
  deregister :callback,   :on_failed, ErrorTracker  # drops just this one
end
```

### Middleware signature

`call(task) { yield }` — always yield or `CMDx::MiddlewareError` is raised. Procs use `next_link.call`:

```ruby
register :middleware, ->(task, &next_link) {
  task.metadata[:tracked] = true
  Timer.track(task.class) { next_link.call }
}
```

No middleware is built into the gem.

### Callback events

`:before_execution`, `:before_validation`, `:on_complete`, `:on_interrupted`, `:on_success`, `:on_skipped`, `:on_failed`, `:on_ok`, `:on_ko`.

Each event has a class-level DSL method: `before_execution :method_name`, `on_failed { |task| ... }`, etc. Callbacks accept Symbol (`task.send`), Proc (`instance_exec(task, &)`), or any `#call(task)`-able. Supports `if:`/`unless:` gates.

Unknown events raise `ArgumentError`. `result` is not yet built during callbacks — subscribe to `:task_executed` telemetry for finalized result data.

## Rails integration

`rails g cmdx:install` creates an initializer and a base task class. `rails g cmdx:task Name` and `rails g cmdx:workflow Name` scaffold classes.

The Railtie wires `config.backtrace_cleaner = Rails.backtrace_cleaner` at load time when `Rails.backtrace_cleaner` is defined — Fault backtraces are cleaned by default under Rails.

## Telemetry

Global `config.telemetry` (or per-task inherited registry) publishes lifecycle events.

Events (`CMDx::Telemetry::EVENTS`):

| Event | Payload keys (in addition to shared) |
|-------|--------------------------------------|
| `:task_started` | — |
| `:task_deprecated` | — |
| `:task_retried` | `attempt:` (Integer) |
| `:task_rolled_back` | — |
| `:task_executed` | `result:` (finalized `Result`) |

Shared `Event` fields: `cid`, `root`, `type`, `task`, `tid`, `name`, `payload`, `timestamp`.

```ruby
CMDx.configure do |c|
  c.telemetry.subscribe(:task_executed) do |event|
    StatsD.timing("cmdx.#{event.task}", event.payload[:result].duration)
  end
end
```

`emit` is a no-op when no subscribers are registered — telemetry is free when unused.

## Inheritance semantics

- `settings`, `retry_on`, `deprecation`, and each registry are inherited via a lazy `dup` (`initialize_copy` on each).
- Subclass changes do not mutate the parent.
- Sibling subclasses are independent once they've cloned.
- `CMDx.reset_configuration!` only invalidates `Task`'s cached ivars — existing subclass caches persist until Ruby reloads the class.

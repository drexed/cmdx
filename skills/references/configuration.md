# Configuration Reference

For full documentation, see [docs/configuration.md](../docs/configuration.md).

## Global Configuration

```ruby
CMDx.configure do |config|
  # Breakpoints
  config.task_breakpoints = "failed"                # when execute! raises (String or Array)
  config.workflow_breakpoints = ["failed"]           # when workflows halt

  # Rollback
  config.rollback_on = ["failed"]                    # statuses that trigger rollback

  # Results
  config.freeze_results = true                       # freeze context/result after execution

  # Debugging
  config.backtrace = false                           # include backtraces in results
  config.backtrace_cleaner = ->(bt) { bt[0..5] }    # filter backtrace lines

  # Error handling
  config.exception_handler = proc { |task, e| APM.report(e) }

  # Logging
  config.logger = Logger.new($stdout)

  # Global registries
  config.middlewares = { correlate: CMDx::Middlewares::Correlate }
  config.callbacks = { audit: AuditCallback }
  config.coercions = { money: MoneyCoercion }
  config.validators = { api_key: ApiKeyValidator }
end
```

### Reset

```ruby
CMDx.reset_configuration!
```

## Per-Task Settings

```ruby
class MyTask < CMDx::Task
  settings(
    # Retries
    retries: 3,                                    # max retry attempts (default: 0)
    retry_on: [Net::TimeoutError, Faraday::Error], # exception classes to retry
    retry_jitter: :exponential_backoff,             # sleep strategy between retries

    # Breakpoints
    task_breakpoints: ["failed"],                  # overrides global for this task
    workflow_breakpoints: ["failed"],              # overrides global for workflows using this task
    breakpoints: ["failed"],                       # shorthand alias

    # Rollback
    rollback_on: ["failed", "skipped"],            # when to call rollback

    # Logging
    log_level: :info,                              # :debug, :info, :warn, :error
    log_formatter: CMDx::LogFormatters::Json.new,  # formatter instance

    # Metadata
    tags: ["billing", "critical"],                 # arbitrary tags for filtering/logging

    # Deprecation
    deprecate: :log,                               # :raise, :log, :warn, or proc

    # Debugging
    backtrace: true,                               # override global
    backtrace_cleaner: ->(bt) { bt },              # override global

    # Error handling
    exception_handler: proc { |task, e| ... },     # override global

    # Logger
    logger: CustomLogger.new,                      # override global

    # Returns (alternative to DSL)
    returns: [:user, :token]
  )
end
```

## Retry Jitter Options

```ruby
# Fixed: no delay
settings retries: 3, retry_on: [Error]

# Exponential backoff: 2^n seconds
settings retries: 3, retry_jitter: :exponential_backoff

# Custom proc: receives retry count (0-indexed)
settings retries: 5, retry_jitter: ->(count) { [count * 0.5, 5.0].min }
```

## Rollback

Define a `rollback` method and configure when it triggers:

```ruby
class ChargeCard < CMDx::Task
  settings rollback_on: ["failed"]

  def work
    context.charge = Gateway.charge!(context.amount)
  end

  def rollback
    Gateway.refund!(context.charge.id) if context.charge
  end
end
```

## Deprecation

```ruby
# Raise on use (development/test)
settings deprecate: :raise

# Log warning
settings deprecate: :log

# Ruby warning
settings deprecate: :warn

# Dynamic
settings deprecate: proc { Rails.env.development? ? :raise : :log }
```

## Log Formatters

```ruby
settings log_formatter: CMDx::LogFormatters::Line.new      # default single-line
settings log_formatter: CMDx::LogFormatters::Json.new      # JSON output
settings log_formatter: CMDx::LogFormatters::KeyValue.new  # key=value pairs
settings log_formatter: CMDx::LogFormatters::Logstash.new  # Logstash-compatible JSON
settings log_formatter: CMDx::LogFormatters::Raw.new       # raw hash
```

## Middleware Registration

### Global

```ruby
CMDx.configure do |config|
  config.middlewares = {
    timeout: [CMDx::Middlewares::Timeout, { seconds: 5 }],
    correlate: CMDx::Middlewares::Correlate
  }
end
```

### Per-task

```ruby
class MyTask < CMDx::Task
  register :middleware, CMDx::Middlewares::Timeout, seconds: 10
  register :middleware, CMDx::Middlewares::Runtime
  register :middleware, CMDx::Middlewares::Correlate, id: proc { |t| t.context.request_id }
  register :middleware, CustomMiddleware, option: "value"
end
```

### Built-in middleware

| Middleware | Purpose | Key options |
|-----------|---------|-------------|
| `Timeout` | Enforces execution time limit | `seconds:` (default: 3, or method name symbol) |
| `Runtime` | Measures execution time | Stores in `result.metadata[:runtime]` |
| `Correlate` | Adds correlation ID | `id:` (proc, method name, or static), `if:`, `unless:` |

## Callback Registration

### Per-task (class methods)

```ruby
before_validation :method_name
before_execution :method_name, if: :condition?
on_success :method_name, unless: -> { context.silent? }
on_failed proc { |task| ErrorLog.record(task) }
on_complete { |task| task.context.completed_at = Time.current }
```

### Global

```ruby
CMDx.configure do |config|
  config.callbacks = {
    on_failed: [FailureTracker, { severity: :high }]
  }
end
```

## Settings Inheritance

Settings cascade: `CMDx.configuration` → parent task → child task. Each level can override.

```ruby
class BaseTask < CMDx::Task
  settings retries: 2, tags: ["base"]
end

class ChildTask < BaseTask
  settings retries: 5  # overrides parent; tags inherited
end
```

## Rails Integration

```ruby
# Generate initializer
rails generate cmdx:install

# Generate task
rails generate cmdx:task ProcessOrder

# Generate locale
rails generate cmdx:locale fr
```

The Railtie automatically:
- Loads CMDx locales into `I18n`
- Sets `backtrace_cleaner` to `Rails.backtrace_cleaner`

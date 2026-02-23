# Configuration

Configure CMDx to customize framework behavior, register components, and control execution flow through global defaults with task-level overrides.

## Configuration Hierarchy

CMDx uses a straightforward two-tier configuration system:

1. **Global Configuration** — Framework-wide defaults
1. **Task Settings** — Class-level overrides using `settings`

Important

Task settings take precedence over global config. Settings are inherited from parent classes and can be overridden in subclasses.

## Global Configuration

Configure framework-wide defaults that apply to all tasks. These settings come with sensible defaults out of the box.

### Breakpoints

Control when `execute!` raises a `CMDx::Fault` based on task status.

```ruby
CMDx.configure do |config|
  config.task_breakpoints = "failed" # String or Array[String]
end
```

For workflows, configure which statuses halt the execution pipeline:

```ruby
CMDx.configure do |config|
  config.workflow_breakpoints = ["skipped", "failed"]
end
```

### Rollback

Control when a `rollback` of task execution is called.

```ruby
CMDx.configure do |config|
  config.rollback_on = ["failed"] # String or Array[String]
end
```

### Backtraces

Enable detailed backtraces for non-fault exceptions to improve debugging. Optionally clean up stack traces to remove framework noise.

Note

In Rails environments, `backtrace_cleaner` defaults to `Rails.backtrace_cleaner.clean`.

```ruby
CMDx.configure do |config|
  # Truthy
  config.backtrace = true

  # Via callable (must respond to `call(backtrace)`)
  config.backtrace_cleaner = AdvanceCleaner.new

  # Via proc or lambda
  config.backtrace_cleaner = ->(backtrace) { backtrace[0..5] }
end
```

### Exception Handlers

Register handlers that run when non-fault exceptions occur.

Tip

Use exception handlers to send errors to your APM of choice.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(task, exception)`)
  config.exception_handler = NewRelicReporter

  # Via proc or lambda
  config.exception_handler = proc do |task, exception|
    APMService.report(exception, extra_data: { task: task.name, id: task.id })
  end
end
```

### Logging

```ruby
CMDx.configure do |config|
  config.logger = CustomLogger.new($stdout)
end
```

### Middlewares

See the [Middlewares](https://drexed.github.io/cmdx/middlewares/#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(task, options)`)
  config.middlewares.register CMDx::Middlewares::Timeout

  # Via proc or lambda
  config.middlewares.register proc { |task, options|
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.debug { "task completed in #{((end_time - start_time) * 1000).round(2)}ms" }
    result
  }

  # With options
  config.middlewares.register AuditTrailMiddleware, service_name: "document_processor"

  # Remove middleware
  config.middlewares.deregister CMDx::Middlewares::Timeout
end
```

Note

Middlewares are executed in registration order. Each middleware wraps the next, creating an execution chain around task logic.

### Callbacks

See the [Callbacks](https://drexed.github.io/cmdx/callbacks/#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via method
  config.callbacks.register :before_execution, :initialize_user_session

  # Via callable (must respond to `call(task)`)
  config.callbacks.register :on_success, LogUserActivity

  # Via proc or lambda
  config.callbacks.register :on_complete, proc { |task|
    execution_time = task.metadata[:runtime]
    Metrics.timer("task.execution_time", execution_time, tags: ["task:#{task.class.name.underscore}"])
  }

  # With options
  config.callbacks.register :on_failure, :send_alert_notification, if: :critical_task?

  # Remove callback
  config.callbacks.deregister :on_success, LogUserActivity
end
```

### Coercions

See the [Attributes - Coercions](https://drexed.github.io/cmdx/attributes/coercions/#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.coercions.register :currency, CurrencyCoercion

  # Via method (must match signature `def coordinates_coercion(value, options)`)
  config.coercions.register :coordinates, :coordinates_coercion

  # Via proc or lambda
  config.coercions.register :tag_list, proc { |value, options|
    delimiter = options[:delimiter] || ','
    max_tags = options[:max_tags] || 50

    tags = value.to_s.split(delimiter).map(&:strip).reject(&:empty?)
    tags.first(max_tags)
  }

  # Remove coercion
  config.coercions.deregister :currency
end
```

### Validators

See the [Attributes - Validations](https://drexed.github.io/cmdx/attributes/validations/#declarations) docs for task level configurations.

```ruby
CMDx.configure do |config|
  # Via callable (must respond to `call(value, options)`)
  config.validators.register :username, UsernameValidator

  # Via method (must match signature `def url_validator(value, options)`)
  config.validators.register :url, :url_validator

  # Via proc or lambda
  config.validators.register :access_token, proc { |value, options|
    expected_prefix = options[:prefix] || "tok_"
    minimum_length = options[:min_length] || 40

    value.start_with?(expected_prefix) && value.length >= minimum_length
  }

  # Remove validator
  config.validators.deregister :username
end
```

## Task Configuration

### Settings

Override global configuration for specific tasks using `settings`:

```ruby
class GenerateInvoice < CMDx::Task
  settings(
    # Global configuration overrides
    task_breakpoints: ["failed"],                # Breakpoint override
    workflow_breakpoints: ["failed"],            # Breakpoint override
    backtrace: true,                             # Toggle backtrace
    backtrace_cleaner: ->(bt) { bt[0..5] },      # Backtrace cleaner
    logger: CustomLogger.new($stdout),           # Custom logger

    # Task configuration settings
    breakpoints: ["failed"],                     # Contextual pointer for :task_breakpoints and :workflow_breakpoints
    log_level: :info,                            # Log level override
    log_formatter: CMDx::LogFormatters::Json.new # Log formatter override
    tags: ["billing", "financial"],              # Logging tags
    deprecate: true,                             # Task deprecations
    retries: 3,                                  # Non-fault exception retries
    retry_on: [External::ApiError],              # List of exceptions to retry on
    retry_jitter: 1,                             # Space between retry iteration, eg: current retry num + 1
    rollback_on: ["failed", "skipped"],          # Rollback on override
    returns: [:user, :account_number]            # Predefines expected return values
  )

  def work
    # Your logic here...
  end
end
```

Important

Retries reuse the same context. By default, all `StandardError` exceptions (including faults) are retried unless you specify `retry_on` option for specific matches.

### Registrations

Register or deregister middlewares, callbacks, coercions, and validators for specific tasks:

```ruby
class SendCampaignEmail < CMDx::Task
  # Middlewares
  register :middleware, CMDx::Middlewares::Timeout
  deregister :middleware, AuditTrailMiddleware

  # Callbacks
  register :callback, :on_complete, proc { |task|
    runtime = task.metadata[:runtime]
    Analytics.track("email_campaign.sent", runtime, tags: ["task:#{task.class.name}"])
  }
  deregister :callback, :before_execution, :initialize_user_session

  # Coercions
  register :coercion, :currency, CurrencyCoercion
  deregister :coercion, :coordinates

  # Validators
  register :validator, :username, :username_validator
  deregister :validator, :url

  def work
    # Your logic here...
  end
end
```

## Configuration Management

### Access

```ruby
# Global configuration access
CMDx.configuration.logger               #=> <Logger instance>
CMDx.configuration.task_breakpoints     #=> ["failed"]
CMDx.configuration.middlewares.registry #=> [<Middleware>, ...]

# Task configuration access
class ProcessUpload < CMDx::Task
  settings(tags: ["files", "storage"])

  def work
    self.class.settings[:logger] #=> Global configuration value
    self.class.settings[:tags]   #=> Task configuration value => ["files", "storage"]
  end
end
```

### Resetting

Warning

Resetting affects your entire application. Use this primarily in test environments.

```ruby
# Reset to framework defaults
CMDx.reset_configuration!

# Verify reset
CMDx.configuration.task_breakpoints     #=> ["failed"] (default)
CMDx.configuration.middlewares.registry #=> Empty registry

# Commonly used in test setup (RSpec example)
RSpec.configure do |config|
  config.before(:each) do
    CMDx.reset_configuration!
  end
end
```

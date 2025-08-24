# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic attribute validation, structured error handling, comprehensive logging, and intelligent execution flow control.

## Table of Contents

- [Installation](#installation)
- [Configuration Hierarchy](#configuration-hierarchy)
- [Global Configuration](#global-configuration)
  - [Breakpoints](#breakpoints)
  - [Logging](#logging)
  - [Middlewares](#middlewares)
  - [Callbacks](#callbacks)
  - [Coercions](#coercions)
  - [Validators](#validators)
- [Task Configuration](#task-configuration)
  - [Settings](#settings)
  - [Registrations](#registrations)
- [Configuration Management](#configuration-management)
  - [Access](#access)
  - [Resetting](#resetting)
- [Task Generator](#task-generator)

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

This creates `config/initializers/cmdx.rb` file.

## Configuration Hierarchy

CMDx follows a two-tier configuration hierarchy:

1. **Global Configuration**: Framework-wide defaults
2. **Task Settings**: Class-level overrides via `settings`

> [!IMPORTANT]
> Task-level settings take precedence over global configuration. Settings are inherited from superclasses and can be overridden in subclasses.

## Global Configuration

Global configuration settings apply to all tasks inherited from `CMDx::Task`.
Globally these settings are initialized with sensible defaults.

### Breakpoints

Raise `CMDx::Fault` when a task called with `execute!` returns a matching status.

```ruby
CMDx.configure do |config|
  # String or Array[String]
  config.task_breakpoints = "failed"
end
```

Workflow breakpoints stops execution and of workflow pipeline on the first task that returns a matching status and throws its `CMDx::Fault`.

```ruby
CMDx.configure do |config|
  # String or Array[String]
  config.workflow_breakpoints = ["skipped", "failed"]
end
```

### Logging

```ruby
CMDx.configure do |config|
  config.logger = CustomLogger.new($stdout)
end
```

### Middlewares

See the [Middelwares](#https://github.com/drexed/cmdx/blob/main/docs/middlewares.md#declarations) docs for task level configurations.

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

> [!NOTE]
> Middlewares are executed in registration order. Each middleware wraps the next, creating an execution chain around task logic.

### Callbacks

See the [Callbacks](#https://github.com/drexed/cmdx/blob/main/docs/callbacks.md#declarations) docs for task level configurations.

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

See the [Attributes - Coercions](#https://github.com/drexed/cmdx/blob/main/docs/attributes/coercions.md#declarations) docs for task level configurations.

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

See the [Attributes - Validations](#https://github.com/drexed/cmdx/blob/main/docs/attributes/validations.md#declarations) docs for task level configurations.

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
    workflow_breakpoints: [],                    # Breakpoint override
    logger: CustomLogger.new($stdout),           # Custom logger

    # Task configuration settings
    breakpoints: ["failed"],                     # Contextual pointer for :task_breakpoints and :workflow_breakpoints
    log_level: :info,                            # Log level override
    log_formatter: CMDx::LogFormatters::Json.new # Log formatter override
    tags: ["billing", "financial"],              # Logging tags
    deprecated: true                             # Task deprecations
  )

  def work
    # Your logic here...
  end
end
```

> [!TIP]
> Use task-level settings for tasks that require special handling, such as financial reporting, external API integrations, or critical system operations.

### Registrations

Register middlewares, callbacks, coercions, and validators on a specific task.
Deregister options that should not be available.

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

> [!WARNING]
> Resetting configuration affects the entire application. Use primarily in test environments or during application initialization.

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

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
rails generate cmdx:task ModerateBlogPost
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/moderate_blog_post.rb
class ModerateBlogPost < CMDx::Task
  def work
    # Your logic here...
  end
end
```

> [!TIP]
> Use **present tense verbs + noun** for task names, eg: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`

---

- **Prev:** [Tips and Tricks](tips_and_tricks.md)
- **Next:** [Basics - Setup](basics/setup.md)

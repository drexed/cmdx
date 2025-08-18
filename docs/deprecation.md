# Task Deprecation

Task deprecation provides a systematic approach to managing legacy tasks in CMDx applications. The deprecation system enables controlled migration paths by issuing warnings, logging messages, or preventing execution of deprecated tasks entirely, helping teams maintain code quality while providing clear upgrade paths.

## Table of Contents

- [TLDR](#tldr)
- [Deprecation Fundamentals](#deprecation-fundamentals)
- [Deprecation Modes](#deprecation-modes)
- [Configuration Examples](#configuration-examples)
- [Migration Strategies](#migration-strategies)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## TLDR

```ruby
# Prevent task execution completely
class Legacy < CMDx::Task
  cmd_setting!(deprecated: :error)
end

# Log deprecation warnings
class Old < CMDx::Task
  cmd_setting!(deprecated: :log)
end

# Issue Ruby warnings
class Obsolete < CMDx::Task
  cmd_setting!(deprecated: :warning)
end

# Usage triggers appropriate deprecation handling
LegacyTask.call   #=> raises DeprecationError
OldTask.call      #=> logs warning via task.logger
ObsoleteTask.call #=> issues Ruby warning
```

## Deprecation Fundamentals

> [!NOTE]
> Task deprecation is configured using the `cmd_setting!` declaration and processed automatically by CMDx before task execution. The deprecation system integrates seamlessly with existing logging and error handling infrastructure.

### How It Works

1. **Configuration**: Tasks declare deprecation mode using `cmd_setting!(deprecated: mode)`
2. **Processing**: CMDx automatically calls `TaskDeprecator.execute(task)` during task lifecycle
3. **Action**: Appropriate deprecation handling occurs based on configured mode
4. **Execution**: Task proceeds normally (unless `:error` mode prevents it)

### Available Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `:error` | Raises `DeprecationError` | Hard deprecation, prevent execution |
| `:log` | Logs warning via `task.logger.warn` | Soft deprecation, track usage |
| `:warning` | Issues Ruby warning | Development alerts |
| `true` | Same as `:log` | Legacy boolean support |
| `nil/false` | No deprecation handling | Default behavior |

## Deprecation Modes

### Error Mode (Hard Deprecation)

> [!WARNING]
> Error mode prevents task execution entirely. Use this for tasks that should no longer be used under any circumstances.

```ruby
class ProcessLegacyPayment < CMDx::Task
  cmd_setting!(deprecated: :error)

  def work
    # This code will never execute
    charge_customer(amount)
  end
end

# Attempting to use deprecated task
result = ProcessLegacyPayment.execute(amount: 100)
#=> raises CMDx::DeprecationError: "ProcessLegacyPaymentTask usage prohibited"
```

### Log Mode (Soft Deprecation)

> [!TIP]
> Log mode allows continued usage while tracking deprecation warnings. Perfect for gradual migration scenarios where immediate replacement isn't feasible.

```ruby
class ProcessOldPayment < CMDx::Task
  cmd_setting!(deprecated: :log)

  def work
    # Task executes normally but logs deprecation warning
    charge_customer(amount)
  end
end

# Task executes with logged warning
result = ProcessOldPayment.execute(amount: 100)
result.successful? #=> true

# Check logs for deprecation warning:
# WARN -- : DEPRECATED: migrate to replacement or discontinue use
```

### Warning Mode (Development Alerts)

> [!NOTE]
> Warning mode issues Ruby warnings visible in development and testing environments. Useful for alerting developers without affecting production logging.

```ruby
class ProcessObsoletePayment < CMDx::Task
  cmd_setting!(deprecated: :warning)

  def work
    # Task executes with Ruby warning
    charge_customer(amount)
  end
end

# Task executes with Ruby warning
result = ProcessObsoletePayment.execute(amount: 100)
# stderr: [ProcessObsoletePaymentTask] DEPRECATED: migrate to replacement or discontinue use

result.successful? #=> true
```

## Configuration Examples

### Environment-Specific Deprecation

```ruby
class ExperimentalFeature < CMDx::Task
  # Different deprecation behavior per environment
  cmd_setting!(
    deprecated: Rails.env.production? ? :error : :warning
  )

  def work
    enable_experimental_feature
  end
end
```

### Conditional Deprecation

```ruby
class LegacyIntegration < CMDx::Task
  # Deprecate only for specific conditions
  cmd_setting!(
    deprecated: -> { ENV['NEW_API_ENABLED'] == 'true' ? :log : nil }
  )

  def work
    call_legacy_api
  end
end
```

## Migration Strategies

> [!IMPORTANT]
> When deprecating tasks, always provide clear migration paths and replacement implementations to minimize disruption.

### Graceful Fallback

```ruby
class Notification < CMDx::Task
  cmd_setting!(deprecated: :log)

  def work
    # Provide fallback while encouraging migration
    logger.warn "Consider migrating to NotificationServiceV2"

    # Delegate to new service but maintain compatibility
    NotificationServiceV2.send_notification(
      recipient: recipient,
      message: message,
      delivery_method: :legacy
    )
  end
end
```

## Error Handling

### Catching Deprecation Errors

```ruby
begin
  result = Legacy.execute(params)
rescue CMDx::DeprecationError => e
  # Handle deprecation gracefully
  Rails.logger.error "Attempted to use deprecated task: #{e.message}"

  # Use replacement task instead
  result = Replacement.execute(params)
end

if result.successful?
  # Process successful result
else
  # Handle task failure
end
```

## Best Practices

### Documentation and Communication

> [!TIP]
> Always document deprecation reasons, timelines, and migration paths. Clear communication prevents confusion and reduces support burden.

```ruby
class LegacyReport < CMDx::Task
  # Document deprecation clearly
  cmd_setting!(deprecated: :log)

  # Class-level documentation
  # @deprecated Use ReportGeneratorV2Task instead
  # @see ReportGeneratorV2Task
  # @note This task will be removed in v2.0.0
  # @since 1.5.0 marked as deprecated

  def work
    # Add inline documentation
    logger.warn <<~DEPRECATION
      LegacyReportTask is deprecated and will be removed in v2.0.0.
      Please migrate to ReportGeneratorV2Task which provides:
      - Better performance
      - Enhanced error handling
      - More flexible output formats

      Migration guide: https://docs.example.com/migration/reports
    DEPRECATION

    generate_legacy_report
  end
end
```

---

- **Prev:** [Testing](testing.md)
- **Next:** [AI Prompts](ai_prompts.md)

# Task Deprecation

Task deprecation provides a systematic approach to managing legacy tasks in CMDx applications. The deprecation system enables controlled migration paths by issuing warnings, logging messages, or preventing execution of deprecated tasks entirely, helping teams maintain code quality while providing clear upgrade paths.

## Table of Contents

- [Modes](#modes)
- [Configuration](#configuration)

##  Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `:raise` | Raises `DeprecationError` | Hard deprecation, prevent execution |
| `:log` | Logs warning via `task.logger.warn` | Soft deprecation, track usage |
| `:warn` | Issues Ruby warning | Development alerts |
| `true` | Same as `:log` | Legacy boolean support |
| `nil/false` | No deprecation handling | Default behavior |

### Raise

`:raise` mode prevents task execution entirely. Use this for tasks that should no longer be used under any circumstances.

```ruby
class ProcessLegacyPayment < CMDx::Task
  settings(deprecated: :raise)

  def work
    # Will never execute...
  end
end

result = ProcessLegacyPayment.execute
#=> raises CMDx::DeprecationError: "ProcessLegacyPayment usage prohibited"
```

### Log

`:log` mode allows continued usage while tracking deprecation warnings. Perfect for gradual migration scenarios where immediate replacement isn't feasible.

```ruby
class ProcessOldPayment < CMDx::Task
  settings(deprecated: :log)

  def work
    # Executes but logs deprecation warning...
  end
end

result = ProcessOldPayment.execute
result.successful? #=> true

# Check logs for deprecation warning:
# WARN -- : DEPRECATED: migrate to replacement or discontinue use
```

### Warn

`:warn` mode issues Ruby warnings visible in development and testing environments. Useful for alerting developers without affecting production logging.

```ruby
class ProcessObsoletePayment < CMDx::Task
  settings(deprecated: :warn)

  def work
    # Executes but emits Ruby warning...
  end
end

result = ProcessObsoletePayment.execute
result.successful? #=> true

# Check STDOUT for deprecation warning:
# stderr: [ProcessObsoletePayment] DEPRECATED: migrate to replacement or discontinue use
```

## Configuration

```ruby
class LegacyIntegration < CMDx::Task
  settings(
    # Via symbol or string
    deprecated: "raise",

    # Via boolean
    deprecated: true,

    # Via method
    deprecated: :deprecate_by_year,

    # Via proc or lambda
    deprecated: -> { Rails.env.local? ? :raise : :log }

    # Via callable (must respond to `call(task)`)
    deprecated: LegacyTaskChecker
  )

  def work
    # Your logic here...
  end

  private

  def deprecate_by_year
    Time.now.year > 2020
  end
end
```

---

- **Prev:** [Testing](testing.md)
- **Next:** [AI Prompts](ai_prompts.md)

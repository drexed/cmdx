# Task Deprecation

Task deprecation provides a systematic approach to managing legacy tasks in CMDx applications. The deprecation system enables controlled migration paths by issuing warnings, logging messages, or preventing execution of deprecated tasks entirely, helping teams maintain code quality while providing clear upgrade paths.

## Table of Contents

- [Modes](#modes)
  - [Raise](#raise)
  - [Log](#log)
  - [Warn](#warn)
- [Declarations](#declarations)
  - [Symbol or String](#symbol-or-string)
  - [Boolean or Nil](#boolean-or-nil)
  - [Method](#method)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)

## Modes

### Raise

`:raise` mode prevents task execution entirely. Use this for tasks that should no longer be used under any circumstances.

> [!WARNING]
> Use `:raise` mode carefully in production environments as it will break existing workflows immediately.

```ruby
class ProcessObsoleteAPI < CMDx::Task
  settings(deprecated: :raise)

  def work
    # Will never execute...
  end
end

result = ProcessObsoleteAPI.execute
#=> raises CMDx::DeprecationError: "ProcessObsoleteAPI usage prohibited"
```

### Log

`:log` mode allows continued usage while tracking deprecation warnings. Perfect for gradual migration scenarios where immediate replacement isn't feasible.

```ruby
class ProcessLegacyFormat < CMDx::Task
  settings(deprecated: :log)

  # Same
  settings(deprecated: true)

  def work
    # Executes but logs deprecation warning...
  end
end

result = ProcessLegacyFormat.execute
result.successful? #=> true

# Deprecation warning appears in logs:
# WARN -- : DEPRECATED: ProcessLegacyFormat - migrate to replacement or discontinue use
```

### Warn

`:warn` mode issues Ruby warnings visible in development and testing environments. Useful for alerting developers without affecting production logging.

```ruby
class ProcessOldData < CMDx::Task
  settings(deprecated: :warn)

  def work
    # Executes but emits Ruby warning...
  end
end

result = ProcessOldData.execute
result.successful? #=> true

# Ruby warning appears in stderr:
# [ProcessOldData] DEPRECATED: migrate to replacement or discontinue use
```

## Declarations

### Symbol or String

```ruby
class OutdatedConnector < CMDx::Task
  # Symbol
  settings(deprecated: :raise)

  # String
  settings(deprecated: "warn")
end
```

### Boolean or Nil

```ruby
class OutdatedConnector < CMDx::Task
  # Deprecates with default :log mode
  settings(deprecated: true)

  # Skips deprecation
  settings(deprecated: false)
  settings(deprecated: nil)
end
```

### Method

```ruby
class OutdatedConnector < CMDx::Task
  # Symbol
  settings(deprecated: :deprecated?)

  def work
    # Your logic here...
  end

  private

  def deprecated?
    Time.now.year > 2024 ? :raise : false
  end
end
```

### Proc or Lambda

```ruby
class OutdatedConnector < CMDx::Task
  # Proc
  settings(deprecated: proc { Rails.env.development? ? :raise : :log })

  # Lambda
  settings(deprecated: -> { Current.tenant.legacy_mode? ? :warn : :raise })
end
```

### Class or Module

```ruby
class OutdatedTaskDeprecator
  def call(task)
    task.class.name.include?("Outdated")
  end
end

class OutdatedConnector < CMDx::Task
  # Class or Module
  settings(deprecated: OutdatedTaskDeprecator)

  # Instance
  settings(deprecated: OutdatedTaskDeprecator.new)
end
```

---

- **Prev:** [Internationalization (i18n)](internationalization.md)
- **Next:** [Workflows](workflows.md)

# Task Deprecation

Manage legacy tasks gracefully with built-in deprecation support. Choose how to handle deprecated tasks—log warnings for awareness, issue Ruby warnings for development, or prevent execution entirely.

## Modes

### Raise

Prevent task execution completely. Perfect for tasks that must no longer run.

!!! warning

    Use `:raise` mode carefully—it will break existing workflows immediately.

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

Allow execution while tracking deprecation in logs. Ideal for gradual migrations.

```ruby
class ProcessLegacyFormat < CMDx::Task
  settings(deprecated: :log)
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

Issue Ruby warnings visible during development and testing. Keeps production logs clean while alerting developers.

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
# [ProcessOldData] DEPRECATED: migrate to a replacement or discontinue use
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

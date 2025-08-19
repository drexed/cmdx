# Task Deprecation

Task deprecation provides a systematic approach to managing legacy tasks in CMDx applications. The deprecation system enables controlled migration paths by issuing warnings, logging messages, or preventing execution of deprecated tasks entirely, helping teams maintain code quality while providing clear upgrade paths.

## Table of Contents

- [Modes](#modes)
  - [Raise](#raise)
  - [Log](#log)
  - [Warn](#warn)
- [Declarations](#declarations)
  - [Symbol or String](#symbol-or-string)
  - [Boolean](#boolean)
  - [Method](#method)
  - [Proc or Lambda](#proc-or-lambda)
  - [Class or Module](#class-or-module)

##  Modes

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

  # Same
  settings(deprecated: true)

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

## Declarations

### Symbol or String

```ruby
class LegacyIntegration < CMDx::Task
  # Symbol
  settings(deprecated: :raise)

  # String
  settings(deprecated: "warn")
end
```

### Boolean

```ruby
class LegacyIntegration < CMDx::Task
  # Deprecates
  settings(deprecated: true)

  # Skips deprecation
  settings(deprecated: false)
  settings(deprecated: nil)
end
```

### Method

```ruby
class LegacyIntegration < CMDx::Task
  # Symbol
  settings(deprecated: :deprecated?)

  def work
    # Your logic here...
  end

  private

  def deprecated?
    Time.now.year > 2020 ? :raise : false
  end
end
```

### Proc or Lambda

```ruby
class LegacyIntegration < CMDx::Task
  # Proc
  settings(deprecated: proc { Rails.env.local? ? :raise : :log })

  # Lambda
  settings(deprecated: -> { Current.user.legacy? ? :warn : :raise })
end
```

### Class or Module

```ruby
class LegacyTaskDeprecator
  def call(task)
    task.class.name.include?("Legacy")
  end
end

class LegacyIntegration < CMDx::Task
  # Class or Module
  settings(deprecated: LegacyTaskDeprecator)

  # Instance
  settings(deprecated: LegacyTaskDeprecator.new)
end
```

---

- **Prev:** [Testing](testing.md)
- **Next:** [AI Prompts](ai_prompts.md)

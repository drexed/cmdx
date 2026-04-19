# Task Deprecation

Mark legacy tasks for graceful migration. Choose how to handle deprecated execution—log warnings for awareness, emit Ruby warnings during development, or block execution entirely.

Deprecation is declared at the **class level** with `deprecation`, **not** through `settings(...)`. Subclasses inherit their parent's deprecation declaration unless they override it. When the action fires, `result.deprecated?` is `true` and a `:task_deprecated` telemetry event is emitted.

!!! note

    Deprecation runs after middlewares (and the `:task_started` telemetry event) but **before** callbacks, input resolution, and `work`. Conditional gates (`:if` / `:unless`) therefore can't read inputs — only the raw `context` and the task instance.

## Modes

### Error

Prevent the task from executing. Use for tasks that must no longer run.

!!! warning

    `:error` breaks every caller of the task immediately. Roll out behind a feature flag (via `:if`) when in doubt.

```ruby
class ProcessObsoleteAPI < CMDx::Task
  deprecation :error

  def work
    # never executes
  end
end

ProcessObsoleteAPI.execute
#=> raises CMDx::DeprecationError: "ProcessObsoleteAPI usage prohibited"
```

### Log

Allow execution and log a warning. Ideal for gradual migrations.

```ruby
class ProcessLegacyFormat < CMDx::Task
  deprecation :log

  def work
    # executes; a warning is written to the task logger
  end
end

result = ProcessLegacyFormat.execute
result.success? #=> true
# logger.warn: "DEPRECATED: ProcessLegacyFormat - migrate to a replacement or discontinue use"
```

### Warn

Emit a Ruby warning to stderr. Visible during development and testing without polluting production logs.

```ruby
class ProcessOldData < CMDx::Task
  deprecation :warn

  def work
    # executes; warning written to stderr
  end
end

result = ProcessOldData.execute
result.success? #=> true
# Kernel.warn: "[ProcessOldData] DEPRECATED: migrate to a replacement or discontinue use"
```

## Declarations

### Symbol

```ruby
class OutdatedConnector < CMDx::Task
  deprecation :error
  # or :log, :warn
end
```

### Method Reference

Dispatched as `task.send(name)`. The method must perform the action itself (raise, log, warn, or no-op); its return value is discarded:

```ruby
class OutdatedConnector < CMDx::Task
  deprecation :handle_deprecation

  def work
    # ...
  end

  private

  def handle_deprecation
    raise CMDx::DeprecationError, "#{self.class} retired" if Time.now.year > 2026

    logger.warn("#{self.class} pending retirement")
  end
end
```

### Proc or Lambda

`instance_exec`'d on the task with the task as the sole block argument:

```ruby
class OutdatedConnector < CMDx::Task
  deprecation proc { |task|
    Rails.env.development? ? raise(CMDx::DeprecationError, "#{task.class} retired") : task.logger.warn("legacy")
  }

  deprecation ->(task) { task.context.tenant.legacy_mode? ? warn("legacy") : nil }
end
```

### Class or Module

Anything that responds to `#call(task)`:

```ruby
class OutdatedTaskDeprecator
  def call(task)
    return unless task.class.name.include?("Outdated")

    raise CMDx::DeprecationError, "#{task.class} usage prohibited"
  end
end

class OutdatedConnector < CMDx::Task
  deprecation OutdatedTaskDeprecator       # class
  deprecation OutdatedTaskDeprecator.new   # instance
end
```

## Conditional Gating

Pass `:if` / `:unless` to skip the deprecation action when the gate fails. Both accept a Symbol (method name), Proc/Lambda, or any callable, and are evaluated against the task instance via `Util.satisfied?`:

```ruby
class OutdatedConnector < CMDx::Task
  deprecation :error, if: -> { Rails.env.production? }
  deprecation :log,   unless: :tenant_grandfathered?

  private

  def tenant_grandfathered?
    context.tenant&.grandfathered?
  end
end
```

!!! note

    Only the **most recent** `deprecation` call wins — there's a single `@deprecation` per class. Combine modes with conditions inside a single Proc when you need branching.

## Inheritance

Subclasses inherit the parent's deprecation. Re-declare to override. `deprecation nil` is a read (returns the inherited value rather than clearing it), so opt out by passing a no-op callable — note that this still marks the result as `deprecated?` and emits `:task_deprecated`, it just suppresses the visible log/warn/raise:

```ruby
class BaseLegacyTask < CMDx::Task
  deprecation :log
end

class StillSupported < BaseLegacyTask
  # inherits :log
end

class FullyRetired < BaseLegacyTask
  deprecation :error
end

class Excluded < BaseLegacyTask
  deprecation ->(_) {}   # opt out
end
```

## Telemetry

When deprecation fires (and conditions pass), Runtime emits the `:task_deprecated` telemetry event before the action runs, and the resulting `Result` reports `deprecated?` as `true`:

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_deprecated, ->(event) {
    StatsD.increment("cmdx.deprecated", tags: ["task:#{event.task_class}"])
  })
end

result = ProcessLegacyFormat.execute
result.deprecated? #=> true
```

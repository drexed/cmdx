# Task Deprecation

Sometimes a task has to stick around for a while—even though you wish it would retire. Deprecation lets you **flag old tasks** so teams migrate gently instead of everything blowing up at once.

You pick what happens when someone runs a deprecated task: **block it**, **log a heads-up**, or **print a Ruby warning** (great in dev, quieter in prod).

Put deprecation on the **class** with `deprecation`, **not** inside `settings(...)`. Subclasses copy the parent’s rule unless they define their own. When deprecation actually runs, `result.deprecated?` is `true` and CMDx emits a `:task_deprecated` telemetry ping—handy for dashboards or metrics.

Note

Deprecation fires **after** middleware (and the `:task_started` event) but **before** callbacks, input resolution, and `work`. That means `:if` / `:unless` gates only see the raw `context` and the task instance—not resolved inputs yet.

## Modes

### Error

**Stop the task cold.** Use this when running the task would be wrong or dangerous.

Warning

`:error` breaks **every** caller immediately. If you’re not 100% sure, roll it out behind a feature flag with `:if` so you can flip it off fast.

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

**Let the task run**, but write a warning to the task logger. Nice when you’re sunsetting something and want logs to tell the story.

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

**Emit a Ruby warning** to stderr—developers and tests see it; production logs stay calmer than with `:log`.

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

The quick path: pass `:error`, `:log`, or `:warn`.

```ruby
class OutdatedConnector < CMDx::Task
  deprecation :error
  # or :log, :warn
end
```

### Method Reference

CMDx calls `task.send(name)`. **Your method** does the real work—raise, log, warn, or nothing. Whatever it returns is ignored.

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

Runs with `instance_exec` on the task; the block gets the task as its argument.

```ruby
class OutdatedConnector < CMDx::Task
  deprecation proc { |task|
    Rails.env.development? ? raise(CMDx::DeprecationError, "#{task.class} retired") : task.logger.warn("legacy")
  }
end

class TenantLegacy < CMDx::Task
  deprecation ->(task) { task.context.tenant.legacy_mode? ? warn("legacy") : nil }
end
```

Warning

You only get **one** `deprecation` per class—each new call **replaces** the last. Need several behaviors? Branch inside a single Proc or callable.

### Class or Module

Anything that responds to `call(task)` works—class or instance.

```ruby
class OutdatedTaskDeprecator
  def call(task)
    return unless task.class.name.include?("Outdated")

    raise CMDx::DeprecationError, "#{task.class} usage prohibited"
  end
end

class OutdatedConnector < CMDx::Task
  deprecation OutdatedTaskDeprecator       # class — must define `.call(task)`
end

class AnotherOutdatedConnector < CMDx::Task
  deprecation OutdatedTaskDeprecator.new   # instance — must define `#call(task)`
end
```

## Conditional Gating

Use `:if` or `:unless` to **skip** the deprecation action when the condition fails. You can pass a symbol (method name), a Proc, or any callable; CMDx checks it with `Util.satisfied?` on the task.

```ruby
class OutdatedConnector < CMDx::Task
  deprecation :error, if: -> { Rails.env.production? }
end

class GrandfatheredTenants < CMDx::Task
  deprecation :log, unless: :tenant_grandfathered?

  private

  def tenant_grandfathered?
    context.tenant&.grandfathered?
  end
end
```

Note

Again: only the **latest** `deprecation` call wins (one slot per class). Fancy branching? Do it inside one Proc.

## Inheritance

Child tasks **inherit** the parent’s deprecation. Redefine `deprecation` on the child to override.

`deprecation nil` **does not clear** inheritance—it reads the inherited value. To “turn off” the visible behavior, use a no-op callable. Heads-up: the result can still be `deprecated?` and still emit `:task_deprecated`; you’re just not logging, warning, or raising.

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

## Custom Actions via the `Deprecators` Registry

Built-ins (`:log`, `:warn`, `:error`) live in `CMDx::Deprecators`—same idea as `Retriers` and `Mergers`. Each action is a callable `call(task)`; return values are ignored. Register yours globally or on a single task:

```ruby
CMDx.configure do |config|
  config.deprecators.register(:bugsnag) do |task|
    Bugsnag.notify("DEPRECATED: #{task.class}", severity: "warning")
  end
end

class OutdatedConnector < CMDx::Task
  deprecation :bugsnag

  # Or scoped to the task class only:
  register :deprecator, :slack, ->(task) { Slack.notify("#{task.class} fired") }
end
```

If a symbol isn’t in the registry, CMDx falls back to a **method on the task**—so `deprecation :handle_deprecation` keeps working the way you expect.

## Telemetry

When deprecation runs (and any `:if` / `:unless` passes), Runtime fires `:task_deprecated` **before** the action. The returned `Result` has `deprecated? == true`.

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_deprecated, ->(event) {
    StatsD.increment("cmdx.deprecated", tags: ["task:#{event.task}"])
  })
end

result = ProcessLegacyFormat.execute
result.deprecated? #=> true
```

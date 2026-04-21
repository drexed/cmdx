# Flipper Feature Flags

Gate task execution on a [Flipper](https://github.com/flippercloud/flipper) feature. Pick the pattern that matches the outcome you want when the flag is off: a **failed** result, or a **skipped** result.

## Failing When the Flag Is Off

A middleware can't throw `skip!` / `fail!` (those must originate inside `work`), but it *can* record an error and yield — the pending error halts the lifecycle with a failed result.

```ruby
# app/middlewares/cmdx_flipper_middleware.rb
class CmdxFlipperMiddleware
  def initialize(feature:, actor: nil)
    @feature = feature
    @actor   = actor
  end

  def call(task)
    actor = resolve_actor(task)

    if Flipper.enabled?(@feature, actor)
      yield
    else
      task.errors.add(:base, "feature #{@feature} is disabled")
      yield
    end
  end

  private

  def resolve_actor(task)
    case @actor
    when nil    then task.context[:user]
    when Symbol then task.send(@actor)
    when Proc   then task.instance_exec(&@actor)
    else             @actor.respond_to?(:call) ? @actor.call(task) : @actor
    end
  end
end
```

```ruby
class NewFeatureTask < CMDx::Task
  register :middleware, CmdxFlipperMiddleware.new(feature: :new_feature)
  register :middleware, CmdxFlipperMiddleware.new(feature: :beta_access, actor: -> { context[:company] })

  def work
    # ...
  end
end
```

## Skipping When the Flag Is Off

For a true `skipped` outcome, check inside `work` and halt with `skip!`:

```ruby
class NewFeatureTask < CMDx::Task
  def work
    skip!("feature new_feature is disabled") unless Flipper.enabled?(:new_feature, context[:user])
    # ...
  end
end
```

## Notes

!!! note

    Middlewares wrap the entire lifecycle but sit **outside** `catch(Signal::TAG)` — calling `skip!` / `fail!` from a middleware escapes as `UncaughtThrowError`. Only `work` can emit those signals. See [Middlewares — Common Patterns](../docs/middlewares.md#common-patterns).

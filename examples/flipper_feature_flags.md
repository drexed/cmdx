# Flipper Feature Flags

Gating an expensive task on a [Flipper](https://github.com/flippercloud/flipper) feature lets a release roll out per-actor without redeploying. The gate has two correct shapes — **failed** when callers must know the request was rejected, **skipped** when the gate is a silent no-op — and the difference shows up in the result so the caller can branch on it.

## Failing when the flag is off

Halt directly with `task.fail!` — Runtime catches signals thrown from middlewares.

```ruby
# app/middlewares/cmdx_flipper_middleware.rb
# frozen_string_literal: true

class CmdxFlipperMiddleware
  def initialize(feature:, actor: :user)
    @feature = feature
    @actor   = actor
  end

  def call(task)
    actor = resolve_actor(task)

    unless Flipper.enabled?(@feature, actor)
      task.fail!("feature #{@feature} is disabled", code: :feature_disabled)
    end

    yield
  end

  private

  def resolve_actor(task)
    case @actor
    when nil    then nil
    when Symbol then task.context[@actor]
    when Proc   then task.instance_exec(&@actor)
    else             @actor.respond_to?(:call) ? @actor.call(task) : @actor
    end
  end
end
```

```ruby
class RebuildSearchIndex < CMDx::Task
  register :middleware, CmdxFlipperMiddleware.new(feature: :search_v2, actor: :company)

  required :company

  def work
    SearchIndex.rebuild!(company)
  end
end
```

## Skipping when the flag is off

When the gate is informational rather than rejected, halt inside `work` so the result reports `skipped?`:

```ruby
class RebuildSearchIndex < CMDx::Task
  required :company

  def work
    skip!("search_v2 disabled for #{company.id}") unless Flipper.enabled?(:search_v2, company)

    SearchIndex.rebuild!(company)
  end
end
```

## Notes

!!! tip "Skip from a middleware too"

    Middlewares can throw any of `success!` / `skip!` / `fail!` / `throw!` — Runtime wraps the chain in `catch(Signal::TAG)`. Use `task.skip!(...)` from the middleware to short-circuit to a skipped result without touching `work`. Throws should happen **before yielding** to `next_link`; signals thrown after the lifecycle has finalized are silently ignored (the lifecycle's own outcome wins).

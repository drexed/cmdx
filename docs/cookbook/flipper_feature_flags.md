# Flipper Feature Flags

Shipping a risky task? Wrap it in a [Flipper](https://github.com/flippercloud/flipper) flag and turn it on per user, per company, or for just your team — no redeploy required.

Two flavors matter for CMDx:

- **Fail when off** — callers get a failed `Result` (good for APIs that should return an error).
- **Skip when off** — callers get a skipped `Result` (good for “nice to have” background work).

## Setup — fail when the flag is off

Middleware calls `task.fail!` before `work`. Runtime turns that into a failed result with your message and code.

```ruby
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

## Usage — fail when off

```ruby
class RebuildSearchIndex < CMDx::Task
  register :middleware, CmdxFlipperMiddleware.new(feature: :search_v2, actor: :company)

  required :company

  def work
    SearchIndex.rebuild!(company)
  end
end
```

## Usage — skip when off

When “off” means “do nothing, but that's OK,” halt inside `work` with `skip!` so the result reports `skipped?`:

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

### Skip from middleware too

Middleware can throw `success!`, `skip!`, `fail!`, or `throw!` — Runtime catches them via `catch(Signal::TAG)`. Use `task.skip!(...)` before `yield` when you want a skipped result without entering `work`. Throw **before** yielding; signals thrown after the lifecycle finishes are ignored.

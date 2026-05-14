# Middlewares

Middlewares are little wrappers around your task. They are the right place for cross-cutting stuff you do not want to copy-paste into every `work` method: auth checks, caching, logging, timeouts, “set this thread-local for the duration of the call,” and so on.

If you have used Rack middleware, you already get the idea: same onion, different layer.

For wiring middleware everywhere at once, see [Global Configuration](configuration.md#middlewares).

## Signature

Each middleware gets the **task** and a **block** that means “run the rest of the chain.” Your job is to call that block when it is time to continue.

- **Class style:** `def call(task) ... yield ... end`
- **Proc style:** capture the block as `&next_link` and call `next_link.call` (Procs cannot `yield` the outer block the same way)

If you never call `yield` / `next_link.call`, CMDx raises `CMDx::MiddlewareError` on purpose so you do not accidentally skip the task body.

**Heads up:** middleware runs while the task is still “in flight.” The final `Result` object is assembled *after* the chain unwinds. Inside middleware, peek at `task.context` and `task.errors`. If you need the finished result every time, Telemetry’s `:task_executed` event is a better hook.

```ruby
class TelemetryMiddleware
  def call(task)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    StatsD.timing("task.duration", duration, tags: ["class:#{task.class.name}"])
  end
end
```

## Execution Order

Think of an onion. The **first** middleware you register sits on the **outside**. It runs first on the way in and last on the way out.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware         # 1st: outermost wrapper
  register :middleware, AuthorizationMiddleware # 2nd: middle wrapper
  register :middleware, CacheMiddleware         # 3rd: innermost wrapper

  def work
    # ...
  end
end

# Execution flow:
# 1. AuditMiddleware (before)
# 2.   AuthorizationMiddleware (before)
# 3.     CacheMiddleware (before)
# 4.       [deprecation, callbacks, input resolution, retried `work`,
#          output verification, rollback, completion callbacks, result finalization]
# 5.     CacheMiddleware (after)
# 6.   AuthorizationMiddleware (after)
# 7. AuditMiddleware (after)
```

## Declarations

### Class or Instance

Use a class when the middleware is reusable. Use an instance when you want to inject config or keep a little state.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, TelemetryMiddleware
  register :middleware, TelemetryMiddleware.new

  register :middleware, MonitoringMiddleware.new(ENV["MONITORING_KEY"])
end
```

### Proc or Lambda

Procs and lambdas need `&next_link` so they can forward the chain explicitly:

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, proc { |task, &next_link|
    Rails.logger.info "[middleware] starting #{task.class}"
    next_link.call
  }

  register :middleware, ->(task, &next_link) {
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    next_link.call
  ensure
    Analytics.track(
      "task.completed",
      class: task.class.name,
      duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    )
  }
end
```

### Inline Block

You can also pass a block straight to `register :middleware`:

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware do |task, &next_link|
    Tenant.with_id(task.context.tenant_id) { next_link.call }
  end
end
```

## Ordering

By default, new middlewares **append** (they move closer to the task, so they run later on the way “in”).

Use `at:` when you care about insertion order. Indexes can be negative and get clamped to the registry size so you do not shoot yourself in the foot.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware              # appended at position 0
  register :middleware, CacheMiddleware              # appended at position 1
  register :middleware, PriorityMiddleware, at: 0    # inserted at 0; pushes others down
end

# Execution order: PriorityMiddleware → AuditMiddleware → CacheMiddleware → [task] → ...
```

To remove middleware, pass the same object you registered, or remove by index:

```ruby
class ProcessCampaign < CMDx::Task
  deregister :middleware, TelemetryMiddleware     # by reference
  deregister :middleware, at: 0                   # by index
end
```

!!! note

    `register` wants **either** a callable **or** a block — not both at once. `deregister` wants **either** a middleware reference **or** `at:` — not both. Mixing those raises `ArgumentError`.

## Conditional Registration

Sometimes you want a middleware registered, but only **sometimes** active. `:if` and `:unless` do that at **run time** (each `#process`), without ripping entries out of the registry.

You can pass a Symbol (method on the task), a Proc, or anything that responds to `#call` with the task — same idea as callback gates.

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware, if: :audited?
  register :middleware, CacheMiddleware, unless: -> { context.skip_cache }
  register :middleware, TracingMiddleware, if: TracingSampler.new # #call(task)

  def work
    # ...
  end

  private

  def audited? = context.tenant_id.present?
end
```

!!! note

    Procs run with `instance_exec` on the task and **no** arguments (`self` is the task). A lambda that insists on one argument will blow up with `ArgumentError`. Classes call `Klass.call(task)`; instances call `instance.call(task)`.

When a gate says “skip this middleware,” the chain just walks past it. Inner middlewares still run. You do not implement the gate by yielding — only the middleware body forwards the chain.

!!! note

    Rule of thumb: `:if` / `:unless` skips the whole middleware. If you still want the wrapper but only sometimes do extra work, see “Conditional wrapping” under Common Patterns.

## Safety

Forgetting to forward the chain is a bug, not a silent “no-op task.” CMDx raises `CMDx::MiddlewareError`:

```ruby
class BrokenMiddleware
  def call(task)
    # forgot to yield
  end
end

class MyTask < CMDx::Task
  register :middleware, BrokenMiddleware
  def work; end
end

MyTask.execute!
#=> raises CMDx::MiddlewareError: "middleware did not yield the next_link"
```

!!! danger "Caution"

    That error is **not** swallowed into a failed `Result` like a normal task failure. It bubbles out of the `catch` boundary for signals. So treat “always forward the chain” as non-negotiable — including inside `rescue` / `ensure` paths.

!!! note

    Any other exception behaves like Ruby: it unwinds the stack. Code *after* `yield` in outer middlewares might not run unless you used `ensure`. Same mental model as Rack: cleanup belongs in `ensure`.

## Common Patterns

### Conditional wrapping

You **must** still call `yield` / `next_link.call` on every path. Branch the *extra* work, not the chain:

```ruby
class FeatureFlag
  def initialize(flag)
    @flag = flag
  end

  def call(task)
    if Flipper.enabled?(@flag)
      Tracker.record(:experimental_path, task.class) { yield }
    else
      yield
    end
  end
end

class ExperimentalTask < CMDx::Task
  register :middleware, FeatureFlag.new(:experimental_path)
end
```

### Halting from middleware

Runtime wraps the middleware chain in `catch(Signal::TAG)`, so a middleware can halt the task directly with `task.success!` / `task.skip!` / `task.fail!` / `task.throw!`. Throw **before** calling `yield` / `next_link.call`; signals thrown after the inner chain finalized are silently dropped (the lifecycle's outcome already won).

```ruby
class FeatureFlagGate
  def initialize(flag)
    @flag = flag
  end

  def call(task)
    task.skip!("#{@flag} disabled", code: :flag_off) unless Flipper.enabled?(@flag)
    yield
  end
end

class ExperimentalTask < CMDx::Task
  register :middleware, FeatureFlagGate.new(:experimental_path)
  def work; end
end

result = ExperimentalTask.execute
result.status            #=> "skipped"
result.reason            #=> "experimental_path disabled"
result.metadata[:code]   #=> :flag_off
```

### Wrapping with thread-local state

```ruby
register :middleware, ->(task, &next_link) {
  Thread.current[:current_user_id] = task.context.user_id
  next_link.call
ensure
  Thread.current[:current_user_id] = nil
}
```

### Enriching result metadata

`task.metadata` is a small hash you can mutate for “stuff about this run” that should ride along on signals and default logging — without stuffing everything into `context`.

```ruby
class RequestIdMiddleware
  def call(task)
    task.metadata[:request_id] = Current.request_id
    yield
  end
end

class ApplicationTask < CMDx::Task
  register :middleware, RequestIdMiddleware
end
```

```ruby
result = ProcessOrder.execute(order_id: 42)
result.metadata[:request_id] #=> "req-abc123"
```

If the task later calls `success!` / `skip!` / `fail!` / `throw!` with its own `metadata:` keys, those win on merge — user code always gets the last word.

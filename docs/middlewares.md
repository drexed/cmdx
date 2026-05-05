# Middlewares

Wrap task execution with middleware for cross-cutting concerns like authentication, caching, telemetry, and timeouts. Think Rack middleware, but for your business logic.

See [Global Configuration](configuration.md#middlewares) for framework-wide setup.

## Signature

Every middleware receives the task and a block: `call(task) { ... }`. Invoke `yield` (or `next_link.call` from a Proc) to run the next link; skipping it raises `CMDx::MiddlewareError`. Middlewares see only the `task` — `Result` is built after the chain unwinds, so read `task.context` / `task.errors` from inside, or subscribe to Telemetry's `:task_executed` event when you need the finalized result.

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

Middleware wraps task execution in layers, like an onion. **First registered = outermost wrapper**, executing in registration order:

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

For reusable middleware logic, use classes (or pass an instance for stateful middleware):

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, TelemetryMiddleware
  register :middleware, TelemetryMiddleware.new

  register :middleware, MonitoringMiddleware.new(ENV["MONITORING_KEY"])
end
```

### Proc or Lambda

Procs and lambdas need an explicit `&next_link` parameter to capture the block (Procs can't `yield` directly):

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

`register :middleware` accepts a block directly:

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware do |task, &next_link|
    Tenant.with_id(task.context.tenant_id) { next_link.call }
  end
end
```

## Ordering

Control insertion position with `at:`. With no `at:`, middlewares append (innermost). The index supports negative values and is clamped to the registry size:

```ruby
class ProcessCampaign < CMDx::Task
  register :middleware, AuditMiddleware              # appended at position 0
  register :middleware, CacheMiddleware              # appended at position 1
  register :middleware, PriorityMiddleware, at: 0    # inserted at 0; pushes others down
end

# Execution order: PriorityMiddleware → AuditMiddleware → CacheMiddleware → [task] → ...
```

Remove by reference or by index:

```ruby
class ProcessCampaign < CMDx::Task
  deregister :middleware, TelemetryMiddleware     # by reference
  deregister :middleware, at: 0                   # by index
end
```

!!! note

    `register` requires either a callable or a block (not both). `deregister` requires either a `middleware` argument or `at:` (not both). Both raise `ArgumentError` otherwise.

## Conditional Registration

`:if` / `:unless` gate a middleware at `#process` time (per task, per execution) without changing the registry. Symbol, Proc, and any `#call`-able resolve against the task — same semantics as callback gates.

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

    Procs are `instance_exec`'d on the task with zero args (`self` is the task) — a 1-arity lambda raises `ArgumentError`. Classes dispatch to `Klass.call(task)`, instances to `instance.call(task)`.

When a gate is falsy, the middleware is skipped and the chain walks straight to the next link — inner middlewares still run. Gates do not need to yield; only the middleware itself does.

!!! note

    Use `:if`/`:unless` to skip the middleware entirely; use inline "Conditional wrapping" when the middleware should wrap but only some side-effects are gated.

## Safety

If a middleware forgets to call `yield` (or `next_link.call`), the chain raises `CMDx::MiddlewareError` instead of silently bypassing the task body:

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

    `MiddlewareError` propagates from both `execute` and `execute!` — it's raised *outside* the signal `catch` boundary and never becomes a failed result. Always yield in every code path (including `rescue`/`ensure`).

!!! note

    Other exceptions propagate out — outer middlewares' after-yield code is skipped unless wrapped in `ensure`. Treat middlewares like Rack: put cleanup in `ensure`.

## Common Patterns

### Conditional wrapping

Middlewares **must** yield on every code path — skipping `yield` raises
`CMDx::MiddlewareError`. To gate side-effects on a condition, branch around the
extra work but always invoke the next link:

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

If you actually need to short-circuit `work` itself (skip the body but still
produce a result), do it from inside the task with `skip!` / `success!` — not
from a middleware.

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

Mutate `task.metadata` to attach request-scoped data (e.g. a Rails `request_id`) without polluting `context`. The hash is merged into every `Signal` the task throws, so it surfaces on `result.metadata` and the default JSON log line — regardless of whether the task succeeds, skips, or fails:

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

Explicit `success!/skip!/fail!/throw!(metadata: {...})` keys are merged on top, so user code can always override middleware-supplied values.

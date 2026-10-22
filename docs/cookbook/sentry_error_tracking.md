# Sentry Error Tracking

Not every failed task is a bug. Some are validation errors; some are `fail!("card declined")` with no exception.

Sentry should still see the ones you care about — with task name, `tid`, and chain ids so the issue page matches your logs.

## Setup — telemetry subscriber

`Runtime` rescues exceptions from `work` and turns them into a failed `Result`. A middleware `rescue` often misses that path.

`:task_executed` fires after the result is final — raised errors **and** logical halts:

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    result = event.payload[:result]
    next if result.success? || result.skipped?

    Sentry.with_scope do |scope|
      scope.set_tags(
        task: event.task.name,
        tid:  event.tid,
        cid:  event.cid,
        xid:  event.xid
      )
      scope.set_context("cmdx", {
        status:   result.status,
        reason:   result.reason,
        retries:  result.retries,
        duration: result.duration,
        metadata: result.metadata
      })

      case result.error
      when Exception
        Sentry.capture_exception(result.error)
      when String
        Sentry.capture_message(
          "Task failed: #{event.task.name} — #{result.error}",
          level: :error
        )
      end
    end
  end
end
```

## Setup — middleware (optional)

Middleware still helps tag scope for paths that escape normal `work` handling — strict `execute!` re-raises, some callbacks:

```ruby
class CmdxSentryMiddleware
  def call(task)
    Sentry.with_scope do |scope|
      scope.set_tags(task: task.class.name, tid: task.tid)
      yield
    end
  end
end

class ApplicationTask < CMDx::Task
  register :middleware, CmdxSentryMiddleware.new
end
```

## Notes

### Result#error

`result.error` is `cause || reason` — the rescued exception when `work` raised, or the string when you used `fail!("...")`. Branch on type so logical failures become messages and real exceptions keep stack traces.

### Drop noisy logical failures

Authorization denials, rate limits, and duplicate idempotency hits are usually not bugs. Skip them with `next if result.metadata[:code].in?(%i[forbidden rate_limited duplicate])`.

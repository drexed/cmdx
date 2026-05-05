# Sentry Error Tracking

Ship unhandled exceptions and logical failures to [Sentry](https://github.com/getsentry/sentry-ruby) with task-scoped context.

## Reporting Exceptions

A middleware wraps `yield` in a Sentry scope and captures anything that escapes.

```ruby
# app/middlewares/cmdx_sentry_middleware.rb
class CmdxSentryMiddleware
  def call(task)
    Sentry.with_scope do |scope|
      scope.set_tags(task: task.class.name, tid: task.tid)
      yield
    end
  rescue StandardError => e
    Sentry.capture_exception(e)
    raise
  end
end
```

```ruby
class ProcessPayment < CMDx::Task
  register :middleware, CmdxSentryMiddleware.new

  def work
    # ...
  end
end
```

## Reporting Logical Failures

A middleware can't see the finalized `Result`; subscribe to CMDx's `:task_executed` event instead.

```ruby
# config/initializers/cmdx_sentry.rb
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    result = event.payload[:result]
    next if result.success?

    Sentry.capture_message(
      "Task #{result.status}: #{result.reason}",
      level: result.failed? ? :error : :warning,
      tags:  { task: event.task.name, tid: event.tid, cid: event.cid }
    )
  end
end
```

## Notes

!!! note

    The middleware re-raises after reporting so CMDx's own `perform_work` rescue can turn the exception into a `failed` result. Swallowing it would leave the task in limbo.

!!! tip

    Only rescued exceptions populate `result.cause`. Failures that originate from `fail!` have `cause: nil`, so inspect `result.reason` / `result.metadata` in the telemetry subscriber.

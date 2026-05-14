# Sentry Error Tracking

A failed task is two distinct events to a tracker: an exception (`StandardError` raised inside `work`, captured by Runtime as `result.cause`) or a logical halt (`fail!("reason")` with no exception). Sentry needs both, and tagged with the task identifiers so the issue page links to the same trace as the application logs.

## Telemetry subscriber

`Runtime#perform_work` rescues every `StandardError` and converts it to a failed `Result`, so a middleware-level `rescue` rarely fires for `work` failures. The reliable hook is the `:task_executed` telemetry event — it sees both raised and logical failures with the finalized `Result` already in hand.

```ruby
# config/initializers/cmdx_sentry.rb
# frozen_string_literal: true

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

      if result.cause
        Sentry.capture_exception(result.cause)
      else
        Sentry.capture_message(
          "Task failed: #{event.task.name} — #{result.reason}",
          level: :error
        )
      end
    end
  end
end
```

## Tagging in-flight spans

A middleware still earns its keep for adding scope to spans that *do* escape `work` — callbacks, `execute!` strict re-raises, retry exhaustion paths:

```ruby
# app/middlewares/cmdx_sentry_middleware.rb
# frozen_string_literal: true

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

!!! note "Cause vs reason"

    `result.cause` is populated only when an exception was rescued. `fail!("not authorized")` produces a failed result with `cause: nil` and `reason: "not authorized"` — the subscriber's `if result.cause` branch routes those to `capture_message` instead of `capture_exception` so they show up as a sibling event class in Sentry.

!!! tip "Drop noisy logical failures"

    Authorization denials, rate limits, and idempotency duplicates are not bugs. Filter them out by `metadata[:code]`: `next if result.metadata[:code].in?(%i[forbidden rate_limited duplicate])`.

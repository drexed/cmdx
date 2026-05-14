# OpenTelemetry Tracing

Each task gets one OTel span. Nested `execute` calls inherit the parent span automatically, so the resulting trace mirrors the `Chain` — root task at the top, every child below it, with timing, status, and exception attached at the level they happened.

## Tracing middleware

```ruby
# app/middlewares/cmdx_otel_middleware.rb
# frozen_string_literal: true

class CmdxOtelMiddleware
  TRACER = OpenTelemetry.tracer_provider.tracer("cmdx", CMDx::VERSION)

  def call(task)
    chain = CMDx::Chain.current

    attributes = {
      "cmdx.task" => task.class.name,
      "cmdx.type" => task.class.type,
      "cmdx.tid"  => task.tid,
      "cmdx.cid"  => chain.id,
      "cmdx.xid"  => chain.xid
    }.compact

    TRACER.in_span(task.class.name, attributes:, kind: :internal) do |span|
      yield
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error(e.message)
      raise
    end
  end
end
```

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CmdxOtelMiddleware.new
end
```

## Recording logical failures

`perform_work` converts `fail!` and rescued exceptions into `Result` signals, so the middleware's `rescue` only catches true unhandled exceptions raised from a callback (`fail!` from a callback is also caught at the signal layer and produces a failed `Result` instead of an exception). Strict-mode `Fault` re-raises happen in `Runtime#execute`'s `ensure` after the middleware chain has already returned and so are **not** rescuable from a middleware — use the `:task_executed` subscriber below to attach finalized status to the still-current span:

```ruby
# config/initializers/cmdx_otel.rb
# frozen_string_literal: true

CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    span = OpenTelemetry::Trace.current_span
    next unless span&.recording?

    result = event.payload[:result]
    span.set_attribute("cmdx.state",       result.state)
    span.set_attribute("cmdx.status",      result.status)
    span.set_attribute("cmdx.duration_ms", result.duration)
    span.set_attribute("cmdx.retries",     result.retries)
    span.set_attribute("cmdx.reason",      result.reason.to_s) if result.reason

    if result.failed?
      span.record_exception(result.cause) if result.cause
      span.status = OpenTelemetry::Trace::Status.error(result.reason.to_s)
    end
  end
end
```

## Notes

!!! tip "Linking propagated failures"

    `result.origin` points at the leaf `Result` that originated a propagated failure (via `throw!` or a re-raised `Fault`). When tasks keep a `tid → SpanContext` map, `span.add_link(OpenTelemetry::Trace::Link.new(origin_span_context))` connects the span where the failure surfaced to the span where it actually happened.

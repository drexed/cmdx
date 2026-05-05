# OpenTelemetry Tracing

Emit an OTel span per CMDx task. Each span inherits the parent task's context, so nested `execute` calls produce a proper trace hierarchy that matches the `Chain`.

## Tracing Middleware

```ruby
# app/middlewares/cmdx_otel_middleware.rb
class CmdxOtelMiddleware
  TRACER = OpenTelemetry.tracer_provider.tracer("cmdx", CMDx::VERSION)

  def call(task)
    attrs = {
      "cmdx.task"  => task.class.name,
      "cmdx.tid"   => task.tid,
      "cmdx.cid"   => CMDx::Chain.current&.id,
      "cmdx.type"  => task.class.type
    }

    TRACER.in_span(task.class.name, attributes: attrs, kind: :internal) do |span|
      yield
    rescue CMDx::Fault => e
      span.set_attribute("cmdx.status", e.result.status)
      span.set_attribute("cmdx.reason", e.result.reason.to_s) if e.result.reason
      span.record_exception(e.result.cause) if e.result.cause
      span.status = OpenTelemetry::Trace::Status.error(e.message)
      raise
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error(e.message)
      raise
    end
  end
end
```

Middlewares rescue `Fault` themselves because CMDx converts raised `Fault`s back into echoed signals after the middleware chain — without the rescue the span wouldn't see the failure.

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CmdxOtelMiddleware.new
end
```

## Recording Logical Failures on the Span

Middlewares don't see the finalized `Result`, so subscribe to `:task_executed` for `skip!` / `fail!` outcomes that never raised:

```ruby
CMDx.configure do |config|
  config.telemetry.subscribe(:task_executed) do |event|
    result = event.payload[:result]
    span   = OpenTelemetry::Trace.current_span
    next unless span&.recording?

    span.set_attribute("cmdx.state",    result.state)
    span.set_attribute("cmdx.status",   result.status)
    span.set_attribute("cmdx.duration", result.duration)
    span.set_attribute("cmdx.reason",   result.reason.to_s) if result.reason
    span.status = OpenTelemetry::Trace::Status.error(result.reason.to_s) if result.failed?
  end
end
```

## Notes

!!! tip

    Add `result.origin` as a span link when chasing root-cause across workflows: it points at the leaf task that originated a propagated failure. Use `span.add_link(OpenTelemetry::Trace::Link.new(origin_span_context))` when you keep a task-id → span-context map.

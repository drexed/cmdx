# OpenTelemetry Tracing

When a request fans out through several tasks, you want one trace that shows who called whom — with timing and errors on the right span.

This recipe gives **one OpenTelemetry span per task**. Nested `execute` calls nest under the parent automatically, mirroring the CMDx [chain](https://drexed.github.io/cmdx/basics/chain/index.md).

## Setup — tracing middleware

Wrap the lifecycle in a span and attach CMDx identifiers as attributes.

```ruby
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

## Setup — logical failures on the span

`fail!` does not raise — it becomes a failed `Result`. The middleware `rescue` above only sees **unhandled** exceptions.

Subscribe to `:task_executed` to stamp the span with the finalized outcome (status, reason, duration):

```ruby
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

Strict-mode `Fault` re-raises after the middleware chain returns, so middleware cannot rescue those — the subscriber is the right place to mark the span.

## Notes

### Linking propagated failures

`result.origin` points at the leaf `Result` when a failure propagated via `throw!` or a re-raised `Fault`. If you keep a `tid → SpanContext` map, `span.add_link(OpenTelemetry::Trace::Link.new(origin_span_context))` connects where the error surfaced to where it actually happened.

# Timeout Guard

A task that calls a slow third party can hold a worker indefinitely when the dependency stalls. Wrapping the lifecycle in stdlib [`Timeout`](https://docs.ruby-lang.org/en/master/Timeout.html) caps the wall-clock budget; Runtime's `rescue StandardError` converts the raised `Timeout::Error` into a failed `Result` with no extra wiring.

## Setup

```ruby
# app/middlewares/cmdx_timeout_middleware.rb
# frozen_string_literal: true

require "timeout"

class CmdxTimeoutMiddleware
  def initialize(seconds:, message: nil)
    @seconds = seconds
    @message = message
  end

  def call(task)
    secs = resolve(task)
    return yield if secs.nil?

    ::Timeout.timeout(secs, ::Timeout::Error, @message || "timed out after #{secs}s") { yield }
  end

  private

  def resolve(task)
    case @seconds
    when nil, Numeric then @seconds
    when Symbol       then task.context[@seconds]
    when Proc         then @seconds.call(task)
    else                   @seconds.respond_to?(:call) ? @seconds.call(task) : @seconds
    end
  end
end
```

## Usage

```ruby
class FetchReport < CMDx::Task
  register :middleware, CmdxTimeoutMiddleware.new(seconds: 5)

  required :report_id, coerce: :integer

  def work
    context.report = ReportClient.fetch(report_id, open_timeout: 1, read_timeout: 4)
  end
end

result = FetchReport.execute(report_id: 42)
result.failed?  # => true when the fetch exceeds 5s
result.reason   # => "[Timeout::Error] timed out after 5s"
result.cause    # => #<Timeout::Error: ...>
```

Dynamic deadlines per-call:

```ruby
register :middleware, CmdxTimeoutMiddleware.new(seconds: :request_deadline)
register :middleware, CmdxTimeoutMiddleware.new(seconds: ->(t) { t.context.slo_ms / 1000.0 })
```

## Notes

!!! warning "stdlib Timeout caveats"

    `Timeout.timeout` on MRI is thread-based — it raises asynchronously inside whatever code is running, including `ensure` blocks. File handles, DB transactions, and network sockets can be left half-cleaned. Always prefer the dependency's own deadline API (`Net::HTTP#open_timeout`/`read_timeout`, `redis-rb` `:timeout`, `faraday` `:timeout`) for resources you own; reach for this middleware only as an outer safety net around code that already cleans up correctly.

!!! tip "Failed vs raised"

    Under `Task.execute`, the `Timeout::Error` is converted to a failed `Result` (`reason` / `cause` populated, `rollback` still runs). Under `Task.execute!`, the original `Timeout::Error` re-raises after lifecycle finalization — strict callers can `rescue Timeout::Error` directly.

!!! tip "Fiber scheduler alternative"

    Inside an `Async { ... }` block, the [`async`](https://github.com/socketry/async) gem's `Task#with_timeout` cancels cooperatively via fiber scheduling instead of thread-level interrupts, sidestepping the `ensure`-block hazard entirely.

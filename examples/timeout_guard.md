# Timeout Guard

Cap how long a task is allowed to run by wrapping it in stdlib [`Timeout`](https://docs.ruby-lang.org/en/master/Timeout.html). When the deadline elapses, Runtime catches the raised exception and produces a **failed** result — no extra wiring needed.

## Setup

```ruby
# app/middlewares/cmdx_timeout_middleware.rb
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
    when Numeric then @seconds
    when Symbol  then task.send(@seconds)
    when Proc    then @seconds.call(task)
    else              @seconds.respond_to?(:call) ? @seconds.call(task) : @seconds
    end
  end
end
```

## Usage

```ruby
class FetchReport < CMDx::Task
  register :middleware, CmdxTimeoutMiddleware.new(seconds: 5)

  required :report_id

  def work
    context.report = ReportClient.fetch(report_id)  # slow network call
  end
end

result = FetchReport.execute(report_id: 42)
result.failed?        #=> true when the fetch exceeds 5s
result.reason         #=> "[Timeout::Error] timed out after 5s"
result.cause          #=> #<Timeout::Error: ...>
```

Dynamic deadlines:

```ruby
register :middleware, CmdxTimeoutMiddleware.new(seconds: :request_deadline)
register :middleware, CmdxTimeoutMiddleware.new(seconds: ->(t) { t.context.slo_ms / 1000.0 })
```

## Notes

!!! warning "stdlib Timeout caveats"

    `Timeout.timeout` on MRI is thread-based and interrupts the running code asynchronously. Operations inside `ensure` blocks — file handles, DB transactions, network sockets — can be left in partially cleaned-up states. Prefer explicit deadline APIs (`Net::HTTP#open_timeout` / `read_timeout`, `redis-rb` `:timeout`, `faraday` `:timeout`) for anything that owns external resources. Reach for this middleware only as a belt-and-suspenders safety net around code you already trust to clean up on its own.

!!! tip "Failed vs raised"

    The timeout raises `Timeout::Error` inside `work`. Under `Task.execute`, Runtime's `rescue StandardError` converts it to a failed result (`result.reason` / `result.cause` populated, `#rollback` still runs). Under `Task.execute!`, the original `Timeout::Error` is re-raised after lifecycle finalization.

!!! tip "Fiber scheduler alternative"

    Inside an `Async { ... }` block, prefer the [`async`](https://github.com/socketry/async) gem's `Task#with_timeout` — it cancels cooperatively via fiber scheduling instead of thread-level interrupts, sidestepping the `ensure`-block hazard entirely.

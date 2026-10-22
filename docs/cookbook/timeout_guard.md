# Timeout Guard

A task calls a slow third party. The API hangs. Your worker sits there forever.

Cap wall-clock time around the task lifecycle with middleware. Runtime turns a timeout exception into a failed `Result` under `execute` — no extra rescue in your task.

Two patterns:

- **Ruby stdlib [`Timeout`](https://docs.ruby-lang.org/en/master/Timeout.html)** — one line, hard ceiling, known MRI caveats.
- **[TIMEx](https://drexed.github.io/timex/getting_started/)** — a shared `Deadline`, cooperative `check!`, and strategies when stdlib `Timeout` is too blunt.

Always set the dependency's own timeout (`read_timeout`, Redis `:timeout`, Faraday `:timeout`) when you can. Use middleware as an outer safety net across the whole task. TIMEx's [getting started guide](https://drexed.github.io/timex/getting_started/#reach-for-native-timeouts-first) walks through that layering in more detail.

## Ruby stdlib Timeout

### Setup

```ruby
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

### Usage

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

Per-call deadlines:

```ruby
register :middleware, CmdxTimeoutMiddleware.new(seconds: :request_deadline)
register :middleware, CmdxTimeoutMiddleware.new(seconds: ->(t) { t.context.slo_ms / 1000.0 })
```

## TIMEx deadline

[TIMEx](https://drexed.github.io/timex/getting_started/) keeps a **`Deadline`** you can pass through loops and HTTP clients. Cooperative code calls **`deadline.check!`** at safe spots; nested work can share one budget instead of stacking unrelated timers.

Use `on_timeout: :raise_standard` in middleware so `TIMEx::TimeoutError` flows through Runtime like any other `StandardError` (stdlib `Timeout::Error` behaves the same way).

### Setup

```ruby
# Gemfile: gem "timex"
require "timex"

class CmdxTimexTimeoutMiddleware
  def initialize(seconds:, strategy: nil, auto_check: nil)
    @seconds     = seconds
    @strategy    = strategy
    @auto_check  = auto_check
  end

  def call(task)
    secs = resolve(task)
    return yield if secs.nil?

    opts = { on_timeout: :raise_standard }
    opts[:strategy]    = @strategy unless @strategy.nil?
    opts[:auto_check]  = @auto_check unless @auto_check.nil?

    TIMEx.deadline(secs, **opts) do |deadline|
      task.context.deadline = deadline
      yield
    end
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

### Usage

Bounded loop with cooperative checkpoints (from the [TIMEx quick start](https://drexed.github.io/timex/getting_started/#quick-start)):

```ruby
class ScoreExportRows < CMDx::Task
  register :middleware, CmdxTimexTimeoutMiddleware.new(seconds: 5.0)

  required :export_id, coerce: :integer

  def work
    rows = ExportRow.where(export_id:)
    context.scores = []

    rows.find_each do |row|
      context.deadline.check!
      context.scores << Scorer.score(row)
    end
  end
end

ScoreExportRows.execute(export_id: 99)
```

HTTP work: shrink the client timeout to match **`deadline.remaining`** so the socket fails inside the same budget:

```ruby
class FetchReport < CMDx::Task
  register :middleware, CmdxTimexTimeoutMiddleware.new(seconds: 5)

  required :report_id, coerce: :integer

  def work
    remaining = context.deadline.remaining
    context.report = ReportClient.fetch(
      report_id,
      open_timeout: 1,
      read_timeout: [remaining, 4].min
    )
  end
end
```

When `work` cannot call `check!` (legacy gem, tight loop you do not own), opt into [auto-check](https://drexed.github.io/timex/auto_check/) or a stronger [strategy](https://drexed.github.io/timex/getting_started/#pick-a-strategy-cheat-sheet) on the middleware:

```ruby
register :middleware, CmdxTimexTimeoutMiddleware.new(seconds: 5, auto_check: true)
register :middleware, CmdxTimexTimeoutMiddleware.new(seconds: 5, strategy: :io)
```

## Notes

### Pick stdlib vs TIMEx

Reach for stdlib `Timeout` when you only need a dumb outer fuse and accept MRI's async-interrupt trade-offs. Reach for TIMEx when you want explicit deadlines, cooperative cancellation, IO/subprocess strategies, or [deadline propagation](https://drexed.github.io/timex/propagation/http_header/) across hops.

### stdlib Timeout caveats

On MRI, `Timeout.timeout` raises asynchronously inside whatever code is running — sometimes inside `ensure` blocks. Sockets and transactions can be left half-cleaned. Prefer library-level timeouts for resources you control; use this wrapper when you need a hard ceiling anyway.

### Failed vs raised

Under `execute`, `Timeout::Error` and `TIMEx::TimeoutError` become failed `Result`s (`rollback` still runs). Under `execute!`, the error re-raises after lifecycle finalization — strict callers can rescue directly.

### Fiber scheduler alternative

Inside `Async { ... }`, the [`async`](https://github.com/socketry/async) gem's `Task#with_timeout` cancels cooperatively and avoids thread-level interrupts.

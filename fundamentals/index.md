# Fundamentals

Once you have [installed CMDx](https://drexed.github.io/cmdx/getting_started/index.md) and run a small task, this page is the mental model: **CERO** for day-to-day design and the **task lifecycle** for debugging middleware, store-backed features, signals, and rollbacks.

## The CERO Pattern

CMDx lines up with a simple mental model: **CERO** (say it like “zero”) — **C**ompose, **E**xecute, **R**eact, **O**bserve.

- **Compose:** write small tasks with clear inputs and outputs; plug them together.
- **Execute:** call `.execute` and let CMDx validate, run `work`, and wrap errors.
- **React:** branch on the result (`success?`, `skipped?`, `failed?`) in your app.
- **Observe:** read structured logs to debug production without guesswork.

```
flowchart LR
    Compose --> Execute
    Execute --> React
    Execute -.-> Observe
```

### Compose

Start with one task that does one thing. Give it typed inputs, optional defaults, and callbacks if you need them. When a process grows, compose several tasks into a workflow instead of growing one giant class.

```ruby
class AnalyzeMetrics < CMDx::Task
  retry_on Net::OpenTimeout, limit: 3, jitter: :exponential

  on_success :track_analysis_completion!

  required :dataset_id, coerce: :integer, numeric: { min: 1 }

  optional :analysis_type, default: "standard"

  output :result, :analyzed_at

  def work
    if dataset.nil?
      fail!("Dataset not found", code: 404)
    elsif dataset.unprocessed?
      skip!("Dataset not ready for analysis")
    else
      context.result = PValueAnalyzer.execute(dataset:, analysis_type:)
      context.analyzed_at = Time.now

      SendAnalyzedEmail.execute(user_id: Current.account.manager_id)
    end
  end

  private

  def dataset
    @dataset ||= Dataset.find_by(id: dataset_id)
  end

  def track_analysis_completion!
    dataset.update!(analysis_result_id: context.result.id)
  end
end
```

```ruby
class SendAnalyzedEmail < CMDx::Task
  def work
    user = User.find(context.user_id)
    MetricsMailer.analyzed(user).deliver_now
  end
end
```

### Execute

Calling `YourTask.execute(...)` gives you a **`Result`** object. Under the hood CMDx coerces and validates arguments, runs `work`, rescues surprises, checks declared outputs, and logs—all in one predictable path.

```ruby
result = AnalyzeMetrics.execute(dataset_id: 42, analysis_type: "bayesian")
```

```ruby
result = AnalyzeMetrics.execute
```

### React

The `Result` is your public API for “what happened?” Use the status helpers and read `reason`, errors, and metadata. For every field and edge case, see [Outcomes](https://drexed.github.io/cmdx/outcomes/result/index.md).

```ruby
if result.success?
  puts "Metrics analyzed at #{result.context.analyzed_at}"
elsif result.skipped?
  puts "Skipped: #{result.reason}"
elsif result.failed?
  puts "Failed: #{result.reason} (code #{result.metadata[:code]})"
end
```

### Observe

Each run writes a structured log line: chain id, task name, status, reason, timing, tags—handy when tasks call other tasks and you need to replay the story. Full field list: [Logging](https://drexed.github.io/cmdx/logging/index.md).

```text
I, [2026-04-19T18:42:37.000000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=1 root=false type="Task" task=SendAnalyzedEmail tid="018c2b95-c091-..." state="complete" status="success" reason=nil metadata={} duration=347.21 ...

I, [2026-04-19T18:42:37.535000Z #3784] INFO -- cmdx: cid="018c2b95-b764-7fff-a1d2-..." index=0 root=true type="Task" task=AnalyzeMetrics tid="018c2b95-b764-..." state="complete" status="success" reason=nil metadata={} duration=1872.04 ...
```

Note

If you ship logs to durable storage, these entries become a time-ordered trail of “who did what, when”—great for audits and spooky production mysteries.

## Task lifecycle (the big picture)

Every `Task.execute` walks the same path: chain setup, a middleware-wrapped lifecycle (deprecation, callbacks, optional [rate limit](https://drexed.github.io/cmdx/rate_limit/index.md) / [circuit breaker](https://drexed.github.io/cmdx/circuit_breaker/index.md) / [lock](https://drexed.github.io/cmdx/locks/index.md) / [idempotency](https://drexed.github.io/cmdx/idempotency/index.md) guards, `work` with optional retries, output checks when `work` did not halt), result finalization **outside** middleware, then freeze and teardown. The diagram below is dense on purpose; bookmark it when you are debugging middleware, store-backed features, signals (`success!`, `skip!`, `fail!`, `throw!`), or rollbacks.

```
flowchart TD
    Invoke([Task.execute]) --> Acquire[Acquire chain if root]
    Acquire --> MW["Middlewares<br/>(catch Signal::TAG)"]
    MW --> TS[:task_started]
    TS --> Dep{Deprecation?}
    Dep -->|":error"| Raise([raise DeprecationError])
    Dep -->|"none / :log / :warn"| Pre[before_execution → before_validation]
    Pre --> Around[around_execution]
    Around --> PW["perform_work:<br/>resolve inputs → rate_limit → circuit_breaker → lock_with → idempotent_by<br/>→ retry_on &#123; work &#125; → verify outputs (unless halted)"]
    PW --> Rollback{"failed?<br/>#rollback?"}
    Rollback -->|yes| RB[#rollback]
    Rollback -->|no| Post
    RB --> Post["after_execution<br/>+ on_state / on_status / on_ok / on_ko"]
    Post --> MWend([leave middleware])
    MWend --> Finalize["Finalize Result + Chain<br/>:task_executed + lifecycle log"]
    Finalize --> Teardown["ensure: freeze + clear chain<br/>(execute! may re-raise here)"]
    Teardown --> Out([Frozen Result])
```

**Rules of thumb (memorize these five):**

- **Middleware wraps deprecation and the callback lifecycle** — from `:task_started` through post-work hooks. Result finalization, lifecycle logging, and teardown run **after** the middleware chain returns (middleware can still halt with `success!` / `skip!` / `fail!` / `throw!` before the inner lifecycle runs).
- **Retries only wrap `work`** — input resolution, rate limiting, circuit breaker, lock, and idempotency run once per invocation (not per retry attempt); output verification also runs once unless `work` halts early.
- **Output verification runs only when `work` does not halt** — `success!`, `skip!`, `fail!`, and `throw!` skip `verify_outputs!`; see [Outputs — Verification behavior](https://drexed.github.io/cmdx/outputs/#verification-behavior).
- **Rollback runs only on failure**, inside `around_execution` and before post-work callbacks, so hooks and telemetry already know whether rollback happened.
- **Teardown always runs** (via `ensure`): the task and context are frozen, errors are captured, and fiber-local chain state is cleared—even when `execute!` re-raises after finalization.

## Designing with tasks

You do not have to read a thick DDD book to benefit. CMDx nudges you toward a few ideas that keep big apps sane:

- **Speak the same words as the business.** Name tasks like the team names workflows: `ApproveLoan`, `ShipOrder`, not `DoStuffService`.
- **Draw boundaries.** Use namespaces so `Billing::GenerateInvoice` and `Shipping::GenerateLabel` do not step on each other’s toes.
- **Keep controllers thin.** Let models hold data; let tasks hold orchestration and rules. That split makes tests smaller and failures easier to find.
- **Choose composition on purpose.** Use [workflows](https://drexed.github.io/cmdx/workflows/index.md) when several steps share one context and you need a clear order. Publish [domain events](https://drexed.github.io/cmdx/cookbook/pub_sub_task_chaining/index.md) when follow-on work should stay decoupled—mailers, analytics, separate queues. [Telemetry](https://drexed.github.io/cmdx/configuration/#telemetry) observes the runtime (`:task_executed`, retries, rollbacks); it is not a substitute for your app’s domain event bus.

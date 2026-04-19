---
date: 2026-06-03
authors:
  - drexed
categories:
  - Tutorials
slug: real-world-cmdx-background-jobs
---

# Real-World CMDx: Background Jobs + CMDx

*Part 3 of the Real-World CMDx series*

*Built on CMDx 2.0 — see the [v2 release post](cmdx-v2-the-runtime-rewrite.md). v2 ships only one Fault class (no `FailFault`/`SkipFault`), drops the built-in `Correlate` middleware in favor of [Telemetry pub/sub](https://drexed.github.io/cmdx/configuration/), and exposes `result.duration` directly.*

There's a natural tension between CMDx tasks and background jobs. Tasks are synchronous, deterministic, and observable. Jobs are asynchronous, retry-prone, and fire-and-forget. When you need both—and you almost always do—the question is how to combine them without losing what makes each one good.

I've seen two bad extremes. The first: every task becomes a Sidekiq job, scattering your business logic across `app/jobs/` and `app/tasks/` with duplicated validation and no shared observability. The second: a single monolithic job that calls a workflow synchronously, tying up a Sidekiq thread for 30 seconds while it processes an order end-to-end.

The sweet spot is using CMDx tasks as the unit of work and Sidekiq as the execution engine. Your Ruby business logic stays in tasks. The job is just the thin wrapper that triggers it. Here's how I set this up in production.

<!-- more -->

## The Basic Pattern

CMDx tasks already have everything you need to run as background jobs. The `execute!` method raises on failure, which is exactly what Sidekiq expects for triggering retries:

```ruby
class Users::SendVerificationJob
  include Sidekiq::Job

  sidekiq_options queue: :mailers, retry: 5

  def perform(user_id)
    user = User.find(user_id)
    Users::SendVerification.execute!(user: user)
  end
end
```

That's it. The job deserializes the ID into an object, the task validates inputs, sends the email, and logs the execution. If the task raises a `CMDx::Fault` or any other exception, Sidekiq retries it.

But there's a subtlety here. `execute!` raises on every failure — both business failures from `fail!` and infrastructure exceptions. You probably don't want Sidekiq retrying a task that failed because the user doesn't exist. It'll fail every time. (Skipped tasks don't raise — `execute!` only re-raises when `result.failed?`, see [`Runtime#raise_signal!`](https://github.com/drexed/cmdx/blob/main/lib/cmdx/runtime.rb).)

## Selective Retries

The fix is to catch business failures and only let infrastructure failures propagate. v2's `CMDx::Fault.matches?` builds a matcher subclass you can use directly in `rescue` (see [`lib/cmdx/fault.rb`](https://github.com/drexed/cmdx/blob/main/lib/cmdx/fault.rb)):

```ruby
PermanentBusinessFailure = CMDx::Fault.matches? do |fault|
  %i[user_not_found already_verified].include?(fault.result.metadata[:code])
end

class Users::SendVerificationJob
  include Sidekiq::Job

  sidekiq_options queue: :mailers, retry: 5

  def perform(user_id)
    user = User.find(user_id)
    Users::SendVerification.execute!(user: user)
  rescue PermanentBusinessFailure => e
    logger.warn "Skipping retry: #{e.message}"
  end
end
```

Permanent failures (user not found, already verified) get logged and discarded — `rescue` only catches the subclass. Transient failures (mail server down, timeout) bypass the matcher, propagate as `CMDx::Fault`, and Sidekiq retries them.

## The Self-Enqueueing Task

For tasks that are *always* run asynchronously, include Sidekiq directly:

```ruby
class Reports::GenerateMonthly < ApplicationTask
  include Sidekiq::Job

  sidekiq_options queue: :reports, retry: 3

  required :account_id, coerce: :integer
  required :month, coerce: :integer, numeric: { within: 1..12 }
  required :year, coerce: :integer, numeric: { min: 2020 }

  output :report, required: true

  def work
    account = Account.find(account_id)

    context.report = ReportBuilder.new(
      account: account,
      period: Date.new(year, month, 1)..Date.new(year, month, -1)
    ).build

    ReportMailer.monthly(account: account, report: context.report).deliver_later
  end

  def perform(context = {})
    self.class.execute!(context)
  end
end
```

Now you have two calling conventions:

```ruby
Reports::GenerateMonthly.execute(account_id: 1, month: 3, year: 2026)

Reports::GenerateMonthly.perform_async("account_id" => 1, "month" => 3, "year" => 2026)
```

Synchronous for tests and console debugging. Asynchronous for production. Same validation, same logging, same observability.

**Important:** Sidekiq serializes arguments as JSON, so keys become strings. CMDx handles this — attributes are accessed by symbol, and context accepts string keys.

## Chain Correlation Across Async Boundaries

Here's a problem: when a workflow enqueues a background job, the job runs in a different fiber (or process). CMDx chains are fiber-local, so the background job starts a new chain. You lose the correlation.

v2 dropped the built-in `Correlate` middleware ([migration guide](https://drexed.github.io/cmdx/v2-migration/#built-ins-removed)) — the replacement is a tiny module that stores the id in fiber-local storage:

```ruby
module Correlate
  KEY = :correlation_id

  def self.id
    Fiber[KEY] ||= SecureRandom.uuid_v7
  end

  def self.use(id)
    previous = Fiber[KEY]
    Fiber[KEY] = id
    yield
  ensure
    Fiber[KEY] = previous
  end

  def call(task)
    id  # ensure populated for the duration of this task
    yield
  end
end

class ApplicationTask < CMDx::Task
  register :middleware, Correlate
end
```

Pass it across the async boundary:

```ruby
class Orders::EnqueueFulfillment < ApplicationTask
  required :order

  def work
    Fulfillment::ProcessJob.perform_async(
      "order_id" => order.id,
      "correlation_id" => Correlate.id
    )

    logger.info "Enqueued fulfillment for order #{order.id}"
  end
end
```

On the receiving side, wrap the job execution in the same correlation scope:

```ruby
class Fulfillment::ProcessJob
  include Sidekiq::Job

  sidekiq_options queue: :fulfillment, retry: 5

  def perform(args)
    Correlate.use(args["correlation_id"]) do
      Fulfillment::Process.execute!(order_id: args["order_id"])
    end
  end
end
```

Now both the synchronous workflow and the background fulfillment share the same correlation id. Search for it in your log aggregator and you see the entire request lifecycle — from cart validation through payment through async fulfillment — as one continuous trace. (For zero-cost observability without a custom middleware, subscribe to `:task_started` Telemetry events instead — see [Telemetry](https://drexed.github.io/cmdx/configuration/).)

## Idempotency for Background Jobs

Background jobs retry. That means your tasks can run multiple times. For tasks that aren't naturally idempotent (charging a card, sending an email), you need a guard.

### Redis-Based Idempotency Middleware

```ruby
class Idempotency
  def initialize(key:, ttl: 300)
    @key_fn = key.respond_to?(:call) ? key : ->(t) { t.context[key] }
    @ttl    = ttl
  end

  def call(task)
    redis_key = "cmdx:idempotency:#{task.class.name}:#{@key_fn.call(task)}"

    if Redis.current.set(redis_key, "processing", nx: true, ex: @ttl)
      begin
        yield
        Redis.current.set(redis_key, "complete", xx: true, ex: @ttl)
      rescue
        Redis.current.del(redis_key)
        raise
      end
    else
      status = Redis.current.get(redis_key)
      throw(CMDx::Signal::TAG, CMDx::Signal.skipped("Already #{status} (idempotency guard)"))
    end
  end
end
```

Middlewares cannot mutate `Result` in v2 (it's frozen, constructed once at the end of the lifecycle). The way to short-circuit a task from middleware is to throw `CMDx::Signal::TAG` directly — Runtime's `catch(Signal::TAG)` block builds the appropriate Result from whatever signal escapes ([`lib/cmdx/runtime.rb`](https://github.com/drexed/cmdx/blob/main/lib/cmdx/runtime.rb)).

Register it on tasks that must not duplicate:

```ruby
class Payments::ChargeCard < Stripe::BaseTask
  register :middleware, Idempotency.new(key: :idempotency_key, ttl: 3600)

  required :stripe_customer
  required :amount_cents, coerce: :integer
  optional :idempotency_key, default: -> { SecureRandom.uuid }

  def work
    context.charge = ::Stripe::Charge.create(
      amount: amount_cents,
      customer: stripe_customer.id,
      idempotency_key: idempotency_key
    )
  end
end
```

First execution processes normally. Retries hit the Redis guard and skip. The task's result has `status: "skipped"` with the reason, visible in your observability pipeline alongside `result.duration` (built into v2 — no middleware required).

## Scheduled Workflows with Cron Jobs

For recurring processes, combine Sidekiq's scheduling with CMDx workflows:

```ruby
class DailyReconciliation < CMDx::Task
  include CMDx::Workflow
  include Sidekiq::Job

  sidekiq_options queue: :critical, retry: 1

  settings(tags: ["reconciliation", "daily"])

  task Reconciliation::FetchBankTransactions
  task Reconciliation::MatchPayments
  task Reconciliation::FlagDiscrepancies
  task Reconciliation::NotifyFinance, if: :has_discrepancies?

  def perform(context = {})
    self.class.execute!(context.merge("date" => Date.yesterday.to_s))
  end

  private

  def has_discrepancies?
    context.discrepancies&.any?
  end
end
```

Schedule it with `sidekiq-cron` or `sidekiq-scheduler`:

```yaml
# config/sidekiq_schedule.yml
daily_reconciliation:
  cron: "0 6 * * *"
  class: DailyReconciliation
  queue: critical
```

Every morning at 6 AM, the full reconciliation pipeline runs as a background job. Each step is logged with chain correlation. If the matching step fails, the workflow halts and Sidekiq retries once. If it fails again, it's in the dead set with full metadata for debugging.

## Error Handling in Async Tasks

Handle the three failure types differently in background jobs:

```ruby
class OrderProcessingJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  sidekiq_retries_exhausted do |job, exception|
    order_id = job["args"].first["order_id"]
    Order.find(order_id).update!(status: :processing_failed)
    AdminNotifier.alert("Order #{order_id} failed permanently: #{exception.message}")
  end

  PermanentFailure = CMDx::Fault.matches? do |f|
    %i[out_of_stock address_invalid].include?(f.result.metadata[:code])
  end

  def perform(args)
    Orders::Fulfill.execute!(order_id: args["order_id"])
  rescue PermanentFailure => e
    Order.find(args["order_id"]).update!(status: :failed, failure_reason: e.message)
  end
end
```

- **Skips**: Task decided there's nothing to do. `execute!` doesn't raise on skip (only on `failed?`), so there's no rescue arm to write — the job returns successfully.
- **Permanent failures**: Business rules that won't change on retry. Caught by the `PermanentFailure` matcher, update the record and stop.
- **Transient failures**: Bypass the matcher, propagate as `CMDx::Fault`, Sidekiq retries with backoff.
- **Exhausted retries**: `sidekiq_retries_exhausted` updates the order status and alerts the team.

## Key Takeaways

1. **Tasks are the unit of work, jobs are the execution engine.** Keep business logic in tasks, use jobs as thin wrappers.

2. **Use `execute!` in jobs.** It raises on `failed?`, which is what Sidekiq needs for retry decisions. Skipped tasks return successfully — no rescue needed.

3. **Use `Fault.matches?` to catch permanent failures.** Build a matcher subclass that filters on `metadata[:code]`; everything else propagates and triggers Sidekiq retries.

4. **Pass a correlation id across async boundaries.** A 10-line `Correlate` module + `Fiber[]` storage gives you the same observability the v1 middleware did.

5. **Add idempotency guards as middleware.** Throw `CMDx::Signal::TAG` from inside the middleware to short-circuit safely; `Result` is frozen and can't be mutated externally.

Background jobs don't have to be a black hole of observability. With CMDx, every async execution is logged, correlated, and traceable — same as synchronous.

Happy coding!

## References

- [Execution](https://drexed.github.io/cmdx/basics/execution/)
- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Faults](https://drexed.github.io/cmdx/interruptions/faults/)
- [Telemetry](https://drexed.github.io/cmdx/configuration/)
- [v2 Migration: Built-ins Removed](https://drexed.github.io/cmdx/v2-migration/#built-ins-removed)

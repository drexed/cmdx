---
date: 2026-05-27
authors:
  - drexed
categories:
  - Tutorials
slug: real-world-cmdx-background-jobs
---

# Real-World CMDx: Background Jobs + CMDx

*Part 3 of the Real-World CMDx series*

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

That's it. The job deserializes the ID into an object, the task validates inputs, sends the email, and logs the execution. If the task raises a `CMDx::FailFault` or any other exception, Sidekiq retries it.

But there's a subtlety here. `execute!` raises on *any* failure — including business logic failures from `fail!`. You probably don't want Sidekiq retrying a task that failed because the user doesn't exist. It'll fail every time.

## Selective Retries

The fix is to catch business failures and only let infrastructure failures propagate:

```ruby
class Users::SendVerificationJob
  include Sidekiq::Job

  sidekiq_options queue: :mailers, retry: 5

  def perform(user_id)
    user = User.find(user_id)
    Users::SendVerification.execute!(user: user)
  rescue CMDx::FailFault => e
    case e.result.metadata[:code]
    when :user_not_found, :already_verified
      logger.warn "Skipping retry: #{e.message}"
    else
      raise
    end
  end
end
```

Business failures that are permanent (user not found, already verified) get logged and discarded. Transient failures (mail server down, timeout) re-raise and Sidekiq retries them.

## The Self-Enqueueing Task

For tasks that are *always* run asynchronously, include Sidekiq directly:

```ruby
class Reports::GenerateMonthly < ApplicationTask
  include Sidekiq::Job

  sidekiq_options queue: :reports, retry: 3

  required :account_id, type: :integer
  required :month, type: :integer, numeric: { within: 1..12 }
  required :year, type: :integer, numeric: { min: 2020 }

  returns :report

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

Here's a problem: when a workflow enqueues a background job, the job runs in a different thread (or process). CMDx chains are thread-local, so the background job starts a new chain. You lose the correlation.

The solution is the `Correlate` middleware:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, CMDx::Middlewares::Correlate
end
```

Now every task execution gets a `correlation_id` in its metadata. Pass it across the async boundary:

```ruby
class Orders::PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task Orders::ValidateCart
  task Orders::CreateOrder
  task Orders::ChargePayment
  task Orders::EnqueueFulfillment

  private

  def physical_goods?
    context.items.any?(&:physical?)
  end
end

class Orders::EnqueueFulfillment < ApplicationTask
  required :order

  def work
    correlation_id = CMDx::Middlewares::Correlate.id

    Fulfillment::ProcessJob.perform_async(
      "order_id" => order.id,
      "correlation_id" => correlation_id
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
    CMDx::Middlewares::Correlate.use(args["correlation_id"]) do
      Fulfillment::Process.execute!(order_id: args["order_id"])
    end
  end
end
```

Now both the synchronous workflow and the background fulfillment share the same `correlation_id`. Search for it in your log aggregator and you see the entire request lifecycle — from cart validation through payment through async fulfillment — as one continuous trace.

## Idempotency for Background Jobs

Background jobs retry. That means your tasks can run multiple times. For tasks that aren't naturally idempotent (charging a card, sending an email), you need a guard.

### Redis-Based Idempotency Middleware

```ruby
class Idempotency
  def call(task, options)
    key = build_key(task, options)
    ttl = options[:ttl] || 300

    if Redis.current.set(key, "processing", nx: true, ex: ttl)
      begin
        yield.tap { |result| Redis.current.set(key, result.status, xx: true, ex: ttl) }
      rescue => e
        Redis.current.del(key)
        raise
      end
    else
      status = Redis.current.get(key)
      if status == "processing"
        task.result.tap { |r| r.skip!("Already processing") }
      else
        task.result.tap { |r| r.skip!("Already completed (#{status})") }
      end
    end
  end

  private

  def build_key(task, options)
    id = if options[:key].respond_to?(:call)
           options[:key].call(task)
         elsif options[:key].is_a?(Symbol)
           task.send(options[:key])
         else
           task.context[:idempotency_key]
         end

    "cmdx:idempotency:#{task.class.name}:#{id}"
  end
end
```

Register it on tasks that must not duplicate:

```ruby
class Payments::ChargeCard < Stripe::BaseTask
  register :middleware, Idempotency,
    key: ->(t) { t.context[:idempotency_key] },
    ttl: 3600

  required :stripe_customer
  required :amount_cents, type: :integer
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

First execution processes normally. Retries hit the Redis guard and skip. The task logs `status: "skipped"` with the reason, so you see it in your observability pipeline.

## Dry Run for Job Previews

Before enqueuing a potentially expensive job, preview what it would do:

```ruby
class Billing::GenerateInvoices < ApplicationTask
  include Sidekiq::Job

  required :billing_period, type: :date

  returns :invoice_count

  def work
    accounts = Account.active.where(billing_day: billing_period.day)

    if dry_run?
      context.invoice_count = accounts.count
      context.estimated_total = accounts.sum(:current_balance)
      logger.info "Dry run: would generate #{context.invoice_count} invoices"
      return
    end

    invoices = accounts.map do |account|
      Invoice.create!(account: account, period: billing_period, amount: account.current_balance)
    end

    context.invoice_count = invoices.size
  end

  def perform(context = {})
    self.class.execute!(context)
  end
end
```

```ruby
preview = Billing::GenerateInvoices.execute(billing_period: Date.today, dry_run: true)
preview.context.invoice_count     #=> 847
preview.context.estimated_total   #=> 1_234_567

Billing::GenerateInvoices.perform_async("billing_period" => Date.today.to_s)
```

Preview synchronously, execute asynchronously. Same task, different mode.

## Scheduled Workflows with Cron Jobs

For recurring processes, combine Sidekiq's scheduling with CMDx workflows:

```ruby
class DailyReconciliation < CMDx::Task
  include CMDx::Workflow
  include Sidekiq::Job

  sidekiq_options queue: :critical, retry: 1

  settings(
    workflow_breakpoints: ["failed"],
    tags: ["reconciliation", "daily"]
  )

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

  def perform(args)
    Orders::Fulfill.execute!(order_id: args["order_id"])
  rescue CMDx::SkipFault => e
    # Skips are fine — order was already fulfilled
    logger.info "Order #{args['order_id']} skipped: #{e.message}"
  rescue CMDx::FailFault => e
    case e.result.metadata[:code]
    when :out_of_stock, :address_invalid
      # Permanent business failures — don't retry
      Order.find(args["order_id"]).update!(status: :failed, failure_reason: e.message)
    else
      raise
    end
  end
end
```

- **Skips**: Task decided there's nothing to do. Log and move on.
- **Permanent failures**: Business rules that won't change on retry. Update the record and stop.
- **Transient failures**: Re-raise for Sidekiq to retry with backoff.
- **Exhausted retries**: Update the order status and alert the team.

## Key Takeaways

1. **Tasks are the unit of work, jobs are the execution engine.** Keep business logic in tasks, use jobs as thin wrappers.

2. **Use `execute!` in jobs.** It raises on failure, which is what Sidekiq needs for retry decisions.

3. **Catch `CMDx::FailFault` selectively.** Permanent business failures shouldn't retry. Transient failures should.

4. **Pass `correlation_id` across async boundaries.** Use `CMDx::Middlewares::Correlate.use` to maintain tracing continuity.

5. **Add idempotency guards for non-idempotent operations.** Redis-based middleware prevents duplicate charges, emails, or any operation that shouldn't repeat.

6. **Preview with dry run, execute with perform_async.** Same task, two modes.

Background jobs don't have to be a black hole of observability. With CMDx, every async execution is logged, correlated, and traceable — same as synchronous.

Happy coding!

## References

- [Execution](https://drexed.github.io/cmdx/basics/execution/)
- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Faults](https://drexed.github.io/cmdx/interruptions/faults/)
- [Logging](https://drexed.github.io/cmdx/logging/)

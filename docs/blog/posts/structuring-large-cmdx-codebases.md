---
date: 2026-04-01
authors:
  - drexed
categories:
  - Tutorials
slug: structuring-large-cmdx-codebases
---

# Structuring Large CMDx Codebases

Your first CMDx task is easy. Your tenth is manageable. But what about your hundredth? I've seen projects where the `app/tasks/` directory becomes a dumping ground—flat files with no organization, inconsistent naming, duplicated middleware registrations, and base classes that try to do everything.

Scaling a CMDx codebase isn't about the framework. It's about the conventions you establish early and enforce consistently. This post is the playbook I wish I had when my first CMDx project grew from 10 tasks to 200.

<!-- more -->

## Directory Structure

The single most impactful decision is how you organize your files. A flat directory stops working around 20 tasks. Group by domain:

```text
app/
└── tasks/
    ├── application_task.rb
    ├── accounts/
    │   ├── activate_account.rb
    │   ├── deactivate_account.rb
    │   ├── verify_email.rb
    │   └── onboard_user.rb          # workflow
    ├── billing/
    │   ├── calculate_tax.rb
    │   ├── charge_card.rb
    │   ├── issue_refund.rb
    │   ├── generate_invoice.rb
    │   └── process_payment.rb       # workflow
    ├── inventory/
    │   ├── receive_stock.rb
    │   ├── reserve_stock.rb
    │   ├── release_reservation.rb
    │   └── fulfill_order.rb         # workflow
    ├── notifications/
    │   ├── send_email.rb
    │   ├── send_sms.rb
    │   └── send_push_notification.rb
    └── reports/
        ├── compile_data.rb
        ├── generate_pdf.rb
        ├── export_csv.rb
        └── create_report.rb         # workflow
```

Each domain directory maps to a Ruby module namespace:

```ruby
# app/tasks/billing/charge_card.rb
class Billing::ChargeCard < ApplicationTask
  # ...
end
```

Workflows live alongside their tasks. When I open `billing/`, I see every operation the billing domain can perform, and `process_payment.rb` tells me how they compose together.

## The Base Class

Every project should have an `ApplicationTask`. This is where you put shared behavior that applies to *all* your tasks:

```ruby
# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  register :middleware, DatabaseTransaction
  register :middleware, SentryTracking

  on_failed :track_failure_metric

  private

  def track_failure_metric
    StatsD.increment("cmdx.task.failed", tags: ["task:#{self.class.name}"])
  end
end
```

Keep it thin. The moment your base class grows beyond 20 lines, you probably need domain-specific base classes instead:

```ruby
# app/tasks/billing/base_task.rb
class Billing::BaseTask < ApplicationTask
  register :middleware, StoplightCircuitBreaker, name: "billing"

  settings(
    retries: 3,
    retry_on: [Stripe::APIConnectionError, Net::OpenTimeout],
    retry_jitter: :exponential_backoff,
    tags: ["billing"]
  )
end
```

```ruby
# app/tasks/billing/charge_card.rb
class Billing::ChargeCard < Billing::BaseTask
  required :amount_cents, type: :integer, numeric: { min: 100 }
  required :customer_id, presence: true

  def work
    context.charge = Stripe::Charge.create(
      amount: amount_cents,
      customer: customer_id
    )
  end

  def rollback
    Stripe::Refund.create(charge: context.charge.id) if context.charge
  end
end
```

Now every billing task inherits circuit breaker protection, retry logic, and proper tagging—without repeating a single line.

## Naming Conventions

Naming consistency makes a codebase scannable. I follow one rule: **Verb + Noun**.

```ruby
# ✓ Good — action is clear
class CreateOrder < CMDx::Task; end
class ValidateAddress < CMDx::Task; end
class SendInvoice < CMDx::Task; end
class RevokeAccess < CMDx::Task; end

# ❌ Bad — ambiguous or passive
class OrderCreation < CMDx::Task; end    # noun, not action
class AddressValidator < CMDx::Task; end # sounds like a utility class
class InvoiceEmail < CMDx::Task; end     # what does it do?
```

Use present tense. `GenerateReport`, not `GeneratingReport` or `ReportGenerated`. The task *does* a thing. Name it like the thing it does.

For workflows, I use a verb that describes the overall process:

```ruby
class PlaceOrder < CMDx::Task       # not "OrderWorkflow"
  include CMDx::Workflow
  # ...
end

class OnboardUser < CMDx::Task      # not "UserOnboardingFlow"
  include CMDx::Workflow
  # ...
end
```

## The Storytelling Pattern

I picked this up from a colleague years ago and it stuck. Your `work` method should read like a story—a sequence of steps described in plain English:

```ruby
class Billing::ProcessPayment < CMDx::Task
  required :order
  required :user

  def work
    verify_payment_method
    authorize_charge
    capture_payment
    record_transaction
  end

  private

  def verify_payment_method
    fail!("No payment method on file", code: :missing_payment) unless user.payment_method?
  end

  def authorize_charge
    context.authorization = PaymentGateway.authorize(
      amount: order.total_cents,
      customer: user.gateway_customer_id
    )
  end

  def capture_payment
    context.charge = PaymentGateway.capture(context.authorization.id)
  end

  def record_transaction
    context.transaction = order.transactions.create!(
      amount_cents: order.total_cents,
      gateway_id: context.charge.id,
      status: :captured
    )
  end
end
```

Someone new to the codebase reads `work` and immediately understands the flow. The private methods fill in the details. This is especially valuable in code review—the reviewer can assess the business logic at the `work` level and drill into implementation details only when needed.

## Style Guide

Consistency in how you structure a task file matters when you have hundreds of them. I follow this order:

```ruby
class Billing::GenerateInvoice < Billing::BaseTask

  # 1. Registrations (middleware, coercions, validators)
  register :middleware, CMDx::Middlewares::Timeout

  # 2. Callbacks
  before_execution :load_account
  on_success :send_invoice_email
  on_complete :track_metrics

  # 3. Settings
  settings(tags: ["billing", "invoices"])

  # 4. Attributes
  required :account_id, type: :integer
  required :line_items, type: :array, presence: true
  optional :due_date, type: :date, default: -> { 30.days.from_now }

  # 5. Returns
  returns :invoice

  # 6. Work
  def work
    build_invoice
    calculate_totals
    finalize
  end

  # 7. Rollback (if needed)
  def rollback
    context.invoice&.void!
  end

  # 8. Private methods
  private

  def load_account
    @account = Account.find(account_id)
  end

  def build_invoice
    context.invoice = @account.invoices.build(due_date: due_date)
  end

  def calculate_totals
    line_items.each { |li| context.invoice.add_line_item(li) }
    context.invoice.calculate_tax!
  end

  def finalize
    context.invoice.save!
  end

  def send_invoice_email
    InvoiceMailer.created(context.invoice).deliver_later
  end

  def track_metrics
    StatsD.increment("billing.invoice.generated")
  end
end
```

When every task follows this structure, you can scan any file and know exactly where to find what you're looking for.

## Shared Middleware Stacks

As your application grows, you'll develop middleware patterns that apply to groups of tasks. Centralize these:

```ruby
# app/middlewares/database_transaction.rb
class DatabaseTransaction
  def call(task, options)
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback if task.result.failed?
    end
  end
end

# app/middlewares/sentry_tracking.rb
class SentryTracking
  def call(task, options)
    Sentry.set_tags(task_class: task.class.name, chain_id: task.chain.id)
    yield
  rescue => e
    Sentry.capture_exception(e, extra: { task_id: task.id })
    raise
  end
end

# app/middlewares/stoplight_circuit_breaker.rb
class StoplightCircuitBreaker
  def call(task, options)
    light = Stoplight(options[:name] || task.class.name)
    light.run { yield }
  rescue Stoplight::Error::RedLight => e
    task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e) }
  end
end
```

Register common stacks in your base classes, not in individual tasks. This prevents drift—every billing task gets the same resilience guarantees.

## Global Configuration

Set sensible defaults once in your initializer:

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  config.log_formatter = CMDx::LogFormatters::Json.new
  config.log_level = Rails.env.production? ? Logger::INFO : Logger::DEBUG
  config.backtrace = !Rails.env.production?
  config.backtrace_cleaner = Rails.backtrace_cleaner.method(:clean)

  config.exception_handler = proc do |task, exception|
    Sentry.capture_exception(exception, extra: {
      task: task.class.name,
      task_id: task.id,
      chain_id: task.chain.id
    })
  end

  config.middlewares.register DatabaseTransaction
  config.middlewares.register SentryTracking
end
```

Then override at the task level only when needed. The configuration hierarchy (global → base class → task) means you define behavior once and override where it matters.

## When to Split a Task

The hardest judgment call is knowing when a task is doing too much. My rule of thumb: **if your `work` method needs more than 5 private methods, it's probably two tasks**.

```ruby
# Too much for one task
class ProcessOrder < CMDx::Task
  def work
    validate_inventory
    calculate_pricing
    apply_discount
    charge_payment
    reserve_stock
    generate_invoice
    send_confirmation
    notify_warehouse
  end
end
```

This belongs in a workflow:

```ruby
class ProcessOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task ValidateInventory
  task CalculatePricing
  task ApplyDiscount
  task ChargePayment
  task ReserveStock
  task GenerateInvoice
  task SendConfirmation
  task NotifyWarehouse, if: :has_physical_items?

  private

  def has_physical_items?
    context.order&.physical_items?
  end
end
```

Each step is independently testable, has its own rollback, shows up in the chain log, and can be reused in other workflows. The workflow itself becomes a readable table of contents for the business process.

## Key Takeaways

1. **Group by domain** — Flat directories don't scale. Use module namespaces.

2. **Layer your base classes** — `ApplicationTask` for global behavior, domain-specific bases for shared resilience patterns.

3. **Verb + Noun naming** — Consistent, scannable, unambiguous.

4. **Storytelling work methods** — The `work` method is the outline; private methods are the chapters.

5. **Consistent file structure** — Registrations, callbacks, settings, attributes, returns, work, rollback, privates. Same order, every time.

6. **Centralize middleware** — Define once in base classes. Override only when needed.

7. **Split early** — If `work` has more than 5 steps, it's a workflow.

These conventions aren't revolutionary. They're the boring, unglamorous decisions that make the difference between a codebase that's a joy to work in and one that makes you dread Monday mornings.

Happy coding!

## References

- [Tips and Tricks](https://drexed.github.io/cmdx/tips_and_tricks/)
- [Configuration](https://drexed.github.io/cmdx/configuration/)
- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Workflows](https://drexed.github.io/cmdx/workflows/)

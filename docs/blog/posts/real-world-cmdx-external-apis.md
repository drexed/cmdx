---
date: 2026-05-20
authors:
  - drexed
categories:
  - Tutorials
slug: real-world-cmdx-external-apis
---

# Real-World CMDx: Integrating External APIs

*Part 2 of the Real-World CMDx series*

External APIs are where clean code goes to die. You write a beautiful service object, ship it, and then the real world hits: Stripe times out, the shipping API returns HTML instead of JSON, the geocoding service rate-limits you at 2 PM on a Tuesday. Suddenly your elegant `PaymentService` is a nest of `rescue` blocks, retry loops, and sleep statements.

I've been on the receiving end of enough 3 AM pages to know that the problem isn't the API—it's how we integrate with it. CMDx gives you a layered defense against flaky I/O: retries for transient failures, timeouts for slow responses, circuit breakers for cascading failures, and structured error handling for everything else. Let me build a complete Stripe payment integration in Ruby to show you how these pieces fit together.

<!-- more -->

## The Naive Approach

Here's what payment integration looks like without structure:

```ruby
def charge_customer(customer_id, amount_cents, currency)
  customer = Customer.find(customer_id)
  charge = Stripe::Charge.create(
    amount: amount_cents,
    currency: currency,
    customer: customer.stripe_id
  )
  customer.charges.create!(stripe_id: charge.id, amount: amount_cents, status: :succeeded)
  charge
rescue Stripe::CardError => e
  # Card declined — that's a business error
  customer.charges.create!(amount: amount_cents, status: :declined, failure_reason: e.message)
  nil
rescue Stripe::RateLimitError, Stripe::APIConnectionError => e
  # Transient — should retry
  sleep(2)
  retry
rescue Stripe::InvalidRequestError => e
  # Bad request — our fault
  Sentry.capture_exception(e)
  nil
rescue => e
  Sentry.capture_exception(e)
  nil
end
```

Retry logic inline. Error reporting scattered. No timeout. No circuit breaker. No observability. And every payment method in the app duplicates this pattern with subtle variations.

## Building the Middleware Stack

With CMDx, we separate infrastructure concerns from business logic using middleware.

### Timeout

Don't let a slow API call hold up your web request:

```ruby
class ExternalApiTask < ApplicationTask
  register :middleware, CMDx::Middlewares::Timeout, seconds: 10
end
```

Any task inheriting from `ExternalApiTask` will fail after 10 seconds with a `CMDx::TimeoutError`. The caller gets a structured failure—no hanging requests, no thread starvation.

### Circuit Breaker

When Stripe is down, stop hammering it:

```ruby
class CircuitBreaker
  def call(task, options)
    service_name = options[:name] || task.class.name
    light = Stoplight(service_name)
    light.run { yield }
  rescue Stoplight::Error::RedLight => e
    task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e) }
  end
end

class Stripe::BaseTask < ExternalApiTask
  register :middleware, CircuitBreaker, name: "stripe"

  settings(
    retries: 3,
    retry_on: [Stripe::APIConnectionError, Net::OpenTimeout, Faraday::ConnectionFailed],
    retry_jitter: ->(retry_num) { 2**retry_num }
  )
end
```

The inheritance chain builds naturally:

```
ApplicationTask            → DatabaseTransaction, ErrorTracking
  ExternalApiTask          → Timeout (10s)
    Stripe::BaseTask       → CircuitBreaker ("stripe"), retries (3x exponential)
```

Every Stripe task gets all of this automatically.

### Error Tracking with Context

```ruby
class ErrorTracking
  def call(task, options)
    Sentry.with_scope do |scope|
      scope.set_tags(
        task_class: task.class.name,
        task_id: task.id,
        chain_id: task.chain.id
      )

      yield.tap do |result|
        if result.failed? && result.cause && !result.cause.is_a?(CMDx::Fault)
          Sentry.capture_exception(result.cause)
        end
      end
    end
  rescue => e
    Sentry.capture_exception(e)
    raise
  end
end
```

The `!result.cause.is_a?(CMDx::Fault)` check is key. When `fail!` is called, CMDx wraps the result's cause in a `FailFault`. We don't want to report those to Sentry — they're intentional business logic, not bugs. Only unexpected exceptions (caught by `execute` and stored as the raw exception) should trigger an alert.

## The Payment Tasks

With infrastructure handled, the tasks themselves are pure business logic.

### Create a Stripe Customer

```ruby
class Stripe::CreateCustomer < Stripe::BaseTask
  required :user

  returns :stripe_customer

  def work
    if user.stripe_customer_id.present?
      context.stripe_customer = ::Stripe::Customer.retrieve(user.stripe_customer_id)
      return
    end

    context.stripe_customer = ::Stripe::Customer.create(
      email: user.email,
      name: user.full_name,
      metadata: { user_id: user.id }
    )

    user.update!(stripe_customer_id: context.stripe_customer.id)
  end

  def rollback
    if context.stripe_customer && user.stripe_customer_id_previously_was.nil?
      ::Stripe::Customer.delete(context.stripe_customer.id)
      user.update!(stripe_customer_id: nil)
    end
  end
end
```

The `rollback` method reverses the operation if a downstream task fails. CMDx calls it automatically when the workflow triggers a rollback.

### Charge the Card

```ruby
class Stripe::ChargeCard < Stripe::BaseTask
  required :stripe_customer
  required :amount_cents, type: :integer, numeric: { min: 50, max: 99_999_999 }
  required :currency, inclusion: { in: %w[usd eur gbp] }
  optional :description
  optional :idempotency_key, default: -> { SecureRandom.uuid }

  returns :charge

  def work
    context.charge = ::Stripe::Charge.create(
      {
        amount: amount_cents,
        currency: currency,
        customer: stripe_customer.id,
        description: description
      },
      idempotency_key: idempotency_key
    )
  rescue ::Stripe::CardError => e
    fail!("Card declined: #{e.message}",
      code: :card_declined,
      decline_code: e.code,
      charge_id: e.json_body&.dig(:error, :charge)
    )
  end

  def rollback
    return unless context.charge

    ::Stripe::Refund.create(charge: context.charge.id)
    logger.info "Refunded charge #{context.charge.id}"
  end
end
```

`Stripe::CardError` is a business error (the card was declined), so we catch it and use `fail!` with structured metadata. All other Stripe exceptions (`APIConnectionError`, `RateLimitError`) propagate naturally and get handled by retries and the circuit breaker.

The `idempotency_key` default ensures that retries don't create duplicate charges.

### Record the Payment

```ruby
class Payments::Record < ApplicationTask
  required :user
  required :charge
  required :amount_cents, type: :integer
  required :currency

  returns :payment

  def work
    context.payment = Payment.create!(
      user: user,
      stripe_charge_id: charge.id,
      amount_cents: amount_cents,
      currency: currency,
      status: :succeeded,
      paid_at: Time.current
    )
  end

  def rollback
    context.payment&.update!(status: :refunded)
  end
end
```

### Send Receipt

```ruby
class Payments::SendReceipt < ApplicationTask
  required :user
  required :payment

  def work
    PaymentMailer.receipt(
      user: user,
      payment: payment
    ).deliver_later
  end
end
```

## The Payment Workflow

```ruby
class Payments::Charge < CMDx::Task
  include CMDx::Workflow

  settings(
    workflow_breakpoints: ["failed"],
    tags: ["payments", "stripe"]
  )

  task Stripe::CreateCustomer
  task Stripe::ChargeCard
  task Payments::Record
  task Payments::SendReceipt
end
```

Four lines. The story is clear: find or create the Stripe customer, charge the card, record the payment, send a receipt.

## The Controller

```ruby
class PaymentsController < ApplicationController
  def create
    result = Payments::Charge.execute(
      user: current_user,
      amount_cents: order.total_cents,
      currency: "usd",
      description: "Order ##{order.number}"
    )

    case result
    in { status: "success" }
      order.update!(payment: result.context.payment, status: :paid)
      redirect_to order_path(order), notice: "Payment successful!"
    in { status: "failed", metadata: { code: :card_declined } }
      redirect_to checkout_path, alert: result.reason
    in { status: "failed" }
      redirect_to checkout_path, alert: "Payment could not be processed. Please try again."
    end
  end
end
```

The controller doesn't know about Stripe, timeouts, retries, or circuit breakers. It sends inputs and handles outcomes.

## What Happens When Stripe Fails

Let's trace through failure scenarios to see how the layers interact.

### Scenario 1: Card Declined

```
Stripe::CreateCustomer  → success (customer exists)
Stripe::ChargeCard      → failed (Card declined: insufficient funds)
  → rollback: nothing to refund
Payments::Record        → never runs (workflow halted)
Payments::SendReceipt   → never runs
Stripe::CreateCustomer  → rollback: skipped (customer existed before)
```

Result: `failed`, `metadata: { code: :card_declined }`. Clean, specific, actionable.

### Scenario 2: Stripe API Timeout

```
Stripe::CreateCustomer  → success
Stripe::ChargeCard      → attempt 1: Net::OpenTimeout → retry
                        → attempt 2: Net::OpenTimeout → retry
                        → attempt 3: success
Payments::Record        → success
Payments::SendReceipt   → success
```

Three retries with exponential backoff (1s, 2s, 4s). The user never knows. Logs show the retry warnings with `chain_id` correlation.

### Scenario 3: Stripe Is Down (Circuit Open)

```
Stripe::CreateCustomer  → failed immediately (CircuitBreaker: Stoplight::Error::RedLight)
```

The circuit breaker trips after enough failures. Subsequent requests fail instantly — no 10-second timeout, no wasted retries. When Stripe recovers, the circuit closes automatically.

### Scenario 4: Charge Succeeds, Recording Fails

```
Stripe::CreateCustomer  → success
Stripe::ChargeCard      → success (charge created in Stripe)
Payments::Record        → failed (database constraint violation)
  → rollback: Payments::Record has nothing to rollback (create failed)
  → rollback: Stripe::ChargeCard refunds the charge
  → rollback: Stripe::CreateCustomer skips (customer existed)
```

The charge was real money. CMDx's automatic rollback calls `Stripe::ChargeCard#rollback`, which issues a refund. The customer isn't charged for a failed order.

## Reusing the Stack for Other APIs

The middleware stack isn't Stripe-specific. Build base classes for any external service:

```ruby
class Shipping::BaseTask < ExternalApiTask
  register :middleware, CircuitBreaker, name: "shippo"

  settings(
    retries: 2,
    retry_on: [Shippo::ConnectionError, Net::ReadTimeout],
    retry_jitter: 1
  )
end

class Geocoding::BaseTask < ExternalApiTask
  register :middleware, CircuitBreaker, name: "google_maps"

  settings(
    retries: 1,
    retry_on: [Google::Apis::TransmissionError],
    retry_jitter: 2
  )
end
```

Same pattern, different thresholds. A shipping API might be slower (allow more retries), while geocoding is a nice-to-have (fail fast with fewer retries).

## Testing External APIs

Test the business logic, mock the API boundary:

```ruby
RSpec.describe Stripe::ChargeCard do
  let(:stripe_customer) { instance_double(Stripe::Customer, id: "cus_test") }

  before do
    CMDx.reset_configuration!
    CMDx::Chain.clear
  end

  it "creates a charge" do
    charge = double(id: "ch_test", amount: 5000)
    allow(::Stripe::Charge).to receive(:create).and_return(charge)

    result = Stripe::ChargeCard.execute(
      stripe_customer: stripe_customer,
      amount_cents: 5000,
      currency: "usd"
    )

    expect(result).to be_success
    expect(result.context.charge.id).to eq("ch_test")
  end

  it "handles card decline" do
    allow(::Stripe::Charge).to receive(:create)
      .and_raise(Stripe::CardError.new("Insufficient funds", "amount", code: "insufficient_funds"))

    result = Stripe::ChargeCard.execute(
      stripe_customer: stripe_customer,
      amount_cents: 5000,
      currency: "usd"
    )

    expect(result).to be_failed
    expect(result.metadata[:code]).to eq(:card_declined)
    expect(result.metadata[:decline_code]).to eq("insufficient_funds")
  end
end
```

Test the middleware stack separately. Test the workflow as an integration. The external API is the only thing you stub—everything else runs for real.

## Key Takeaways

1. **Separate infrastructure from logic.** Timeouts, retries, and circuit breakers live in middleware. Tasks contain business logic only.

2. **Layer your defenses.** Timeout catches slow calls. Retries handle transient failures. Circuit breakers prevent cascading outages. Each layer catches what the others miss.

3. **Use `fail!` for business errors, let exceptions propagate for infrastructure errors.** A declined card is `fail!`. A network timeout is an exception that triggers retries.

4. **Rollback compensates for real side effects.** When you charge a credit card and a downstream step fails, the rollback issues a refund. CMDx calls it automatically.

5. **Build reusable base classes per service.** `Stripe::BaseTask`, `Shipping::BaseTask`, `Geocoding::BaseTask` — each with appropriate resilience settings.

The middleware stack does the hard, boring, critical work of making external API calls reliable. Your tasks just do the work.

Happy coding!

## References

- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Configuration](https://drexed.github.io/cmdx/configuration/)
- [Halt](https://drexed.github.io/cmdx/interruptions/halt/)
- [Faults](https://drexed.github.io/cmdx/interruptions/faults/)

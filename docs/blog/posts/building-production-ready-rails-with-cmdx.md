---
date: 2026-03-04
authors:
  - drexed
categories:
  - Tutorials
slug: building-production-ready-rails-with-cmdx
---

# Building Production-Ready Rails Applications with CMDx: A Complete Guide

I've been building Ruby on Rails applications for over a decade, and if there's one thing that keeps me up at night, it's the state of business logic in most codebases. You know what I'm talking about—fat controllers, bloated models, service objects that look like they were written by five different people on five different days. We've all inherited that one `OrderService` class with 800 lines of spaghetti code and a comment at the top that says "TODO: refactor this."

This guide is everything I wish I had when I started taking service objects seriously. We're going to build a complete order processing system from scratch, and by the end, you'll understand how CMDx transforms chaotic business logic into clean, observable, maintainable code.

<!-- more -->

## The Problem We're Solving

Let me show you what we're up against. Here's a typical Rails service object I encounter in the wild:

```ruby
class OrderService
  def initialize(user, cart_items, payment_params)
    @user = user
    @cart_items = cart_items
    @payment_params = payment_params
  end

  def process
    return { success: false, error: "Cart is empty" } if @cart_items.empty?

    order = Order.create!(user: @user, items: @cart_items, total: calculate_total)

    begin
      charge = Stripe::Charge.create(
        amount: order.total_cents,
        customer: @user.stripe_customer_id
      )
      order.update!(stripe_charge_id: charge.id, status: :paid)
    rescue Stripe::CardError => e
      order.update!(status: :payment_failed)
      return { success: false, error: e.message }
    end

    InventoryService.new(order).reserve!
    OrderMailer.confirmation(@user, order).deliver_later
    Analytics.track("order_completed", user_id: @user.id, order_id: order.id)

    { success: true, order: order }
  rescue => e
    Rails.logger.error("Order failed: #{e.message}")
    { success: false, error: "Something went wrong" }
  end

  private

  def calculate_total
    @cart_items.sum { |item| item[:price] * item[:quantity] }
  end
end
```

What's wrong with this? *Everything*:

- **Mixed concerns**: Validation, persistence, payment, inventory, email, and analytics all tangled together
- **Inconsistent error handling**: Some errors return hashes, others might raise
- **No observability**: That `Rails.logger.error` tells us nothing useful
- **Impossible to test**: You'd need to mock half the world
- **No retry logic**: Network hiccup? Enjoy that failed order

Let's rebuild this the right way.

## Setting Up CMDx in Rails

First, let's get CMDx installed. Add it to your Gemfile:

```ruby
gem "cmdx"
```

Then run the installer:

```bash
bundle install
rails generate cmdx:install
```

This creates `config/initializers/cmdx.rb` with sensible defaults. For our order system, let's configure it:

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  config.log_formatter = CMDx::LogFormatters::Json.new
  config.log_level = Rails.env.production? ? Logger::INFO : Logger::DEBUG
end
```

I also like to organize my tasks in `app/tasks/`:

```bash
mkdir -p app/tasks/orders
```

## Your First Task: Validating the Cart

Let's start simple. Every order begins with validation:

```ruby
# app/tasks/orders/validate_cart.rb
class Orders::ValidateCart < CMDx::Task
  def work
    if context.cart_items.blank?
      fail!("Cart is empty", code: :empty_cart)
    end

    if context.cart_items.any? { |item| item[:quantity] <= 0 }
      fail!("Invalid item quantity", code: :invalid_quantity)
    end

    context.cart_total = calculate_total
    context.item_count = context.cart_items.sum { |item| item[:quantity] }
  end

  private

  def calculate_total
    context.cart_items.sum { |item| item[:price] * item[:quantity] }
  end
end
```

See what's happening here? The task has one job: validate the cart. It uses `fail!` to stop execution when something's wrong, and it enriches the context with calculated values for downstream tasks.

Let's run it:

```ruby
result = Orders::ValidateCart.execute(cart_items: [])

result.success?           # => false
result.failed?            # => true
result.reason             # => "Cart is empty"
result.metadata[:code]    # => :empty_cart
```

Every execution returns a `Result` object. Always. No surprises.

## Adding Attributes: Self-Documenting Interfaces

That first task works, but it's not telling us what data it expects. Let's make it explicit with attributes:

```ruby
# app/tasks/orders/validate_cart.rb
class Orders::ValidateCart < CMDx::Task
  required :cart_items, type: :array, presence: true
  required :user_id, type: :integer, numeric: { min: 1 }

  def work
    if cart_items.any? { |item| item[:quantity] <= 0 }
      fail!("Invalid item quantity", code: :invalid_quantity)
    end

    context.cart_total = calculate_total
    context.item_count = cart_items.sum { |item| item[:quantity] }
  end

  private

  def calculate_total
    cart_items.sum { |item| item[:price] * item[:quantity] }
  end
end
```

Now the task declares its contract. Notice how I'm using `cart_items` directly instead of `context.cart_items`—CMDx creates accessor methods for each attribute. The input gets coerced to the right type and validated before `work` even runs.

Try calling it with bad data:

```ruby
result = Orders::ValidateCart.execute(cart_items: nil, user_id: "abc")

result.failed?            # => true
result.metadata[:errors]
# => {
#      messages: {
#        cart_items: ["can't be blank"],
#        user_id: ["is not a number"]
#      }
#    }
```

Validation happens automatically. Your `work` method can trust its inputs.

## Building the Payment Task

Now let's tackle payments. This is where things get interesting:

```ruby
# app/tasks/orders/process_payment.rb
class Orders::ProcessPayment < CMDx::Task
  required :user, presence: true
  required :amount_cents, type: :integer, numeric: { min: 100 }
  required :order

  optional :idempotency_key, default: -> { SecureRandom.uuid }

  def work
    if user.stripe_customer_id.blank?
      fail!("No payment method on file", code: :no_payment_method)
    end

    charge = Stripe::Charge.create(
      amount: amount_cents,
      currency: "usd",
      customer: user.stripe_customer_id,
      idempotency_key: idempotency_key,
      metadata: { order_id: order.id }
    )

    context.charge = charge
    context.charged_at = Time.current

    logger.info "Payment successful: #{charge.id}"
  end

  def rollback
    return unless context.charge

    Stripe::Refund.create(charge: context.charge.id)
    logger.info "Payment refunded: #{context.charge.id}"
  end
end
```

A few things to notice:

1. **Dynamic defaults**: The `idempotency_key` generates a UUID at execution time
2. **Logging**: The `logger` is built-in and correlates with the execution chain
3. **Rollback**: If something fails downstream, this task knows how to undo itself

What about Stripe exceptions? CMDx handles them gracefully:

```ruby
# If Stripe raises Stripe::CardError
result = Orders::ProcessPayment.execute(
  user: user,
  amount_cents: 5000,
  order: order
)

result.failed?   # => true
result.reason    # => "[Stripe::CardError] Your card was declined"
result.cause     # => The actual Stripe::CardError exception
```

The exception is captured, not swallowed. You get a clean result object AND the original exception for debugging.

## Handling Inventory with Skip Logic

Not everything is a failure. Sometimes there's just nothing to do:

```ruby
# app/tasks/orders/reserve_inventory.rb
class Orders::ReserveInventory < CMDx::Task
  required :order

  def work
    if order.digital_only?
      skip!("Digital order, no inventory needed")
    end

    order.line_items.each do |line_item|
      reservation = InventoryReservation.create!(
        product_id: line_item.product_id,
        quantity: line_item.quantity,
        order_id: order.id,
        expires_at: 30.minutes.from_now
      )
      context.reservations ||= []
      context.reservations << reservation
    end

    context.inventory_reserved_at = Time.current
  end

  def rollback
    return if context.reservations.blank?

    context.reservations.each(&:release!)
    logger.info "Released #{context.reservations.size} inventory reservations"
  end
end
```

When a task calls `skip!`, it's a *successful* outcome—the task did exactly what it should by recognizing there was nothing to do. This is different from `fail!`, which indicates something went wrong.

```ruby
result = Orders::ReserveInventory.execute(order: digital_order)

result.skipped?  # => true
result.good?     # => true (skipped is not a failure)
result.reason    # => "Digital order, no inventory needed"
```

## Sending Notifications with Callbacks

After an order succeeds, we need to send confirmations. This is a perfect use case for callbacks—side effects that happen *because* something succeeded:

```ruby
# app/tasks/orders/create_order.rb
class Orders::CreateOrder < CMDx::Task
  on_success :send_confirmation_email
  on_success :notify_warehouse
  on_failed :alert_support_team

  required :user
  required :cart_items, type: :array
  required :cart_total, type: :big_decimal

  def work
    order = Order.create!(
      user: user,
      status: :pending,
      total_cents: (cart_total * 100).to_i
    )

    cart_items.each do |item|
      order.line_items.create!(
        product_id: item[:product_id],
        quantity: item[:quantity],
        price_cents: (item[:price] * 100).to_i
      )
    end

    context.order = order
  end

  private

  def send_confirmation_email
    OrderMailer.confirmation(user, context.order).deliver_later
  end

  def notify_warehouse
    return unless context.order.physical_items?

    WarehouseNotifier.new_order(context.order).deliver_later
  end

  def alert_support_team
    SupportAlerts.order_failed(
      user_id: user.id,
      reason: result.reason,
      metadata: result.metadata
    )
  end
end
```

Callbacks keep your `work` method focused on the core logic. The notifications happen automatically based on the outcome.

## Wrapping Everything with Middlewares

What if we need database transactions? Or request tracing? That's where middlewares come in—they wrap the entire execution:

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
```

```ruby
# app/middlewares/sentry_tracking.rb
class SentryTracking
  def call(task, options)
    Sentry.set_tags(
      task_class: task.class.name,
      chain_id: task.chain.id
    )
    yield
  rescue => e
    Sentry.capture_exception(e, extra: {
      task_id: task.id,
      context: task.context.to_h
    })
    raise
  end
end
```

Apply them to your tasks:

```ruby
class Orders::CreateOrder < CMDx::Task
  register :middleware, DatabaseTransaction
  register :middleware, SentryTracking

  # ... rest of the task
end
```

Now every execution is wrapped in a transaction and traced in Sentry. The middleware yields to run the task, then can react to the outcome.

## Orchestrating with Workflows

We've built individual tasks. Now let's wire them together:

```ruby
# app/tasks/orders/place_order.rb
class Orders::PlaceOrder < CMDx::Task
  include CMDx::Workflow

  settings workflow_breakpoints: ["failed"]

  task Orders::ValidateCart
  task Orders::CreateOrder
  task Orders::ProcessPayment
  task Orders::ReserveInventory, if: :has_physical_items?
  task Orders::FinalizeOrder

  private

  def has_physical_items?
    context.order&.physical_items?
  end
end
```

That's it. Five lines of task declarations and the entire order flow is visible at a glance.

The `workflow_breakpoints: ["failed"]` setting means if any task fails, the workflow stops immediately. Skipped tasks don't halt the flow—they're expected behavior.

Let's execute it:

```ruby
result = Orders::PlaceOrder.execute(
  user: current_user,
  cart_items: [
    { product_id: 1, quantity: 2, price: 29.99 },
    { product_id: 2, quantity: 1, price: 49.99 }
  ]
)

if result.success?
  redirect_to order_path(result.context.order)
else
  flash[:error] = result.reason
  render :checkout
end
```

## The Power of Chain Correlation

Here's where CMDx really shines. Every task in that workflow shares the same `chain_id`. Check your logs:

```json
{"index":1,"chain_id":"abc123","class":"Orders::ValidateCart","status":"success","metadata":{"runtime":12}}
{"index":2,"chain_id":"abc123","class":"Orders::CreateOrder","status":"success","metadata":{"runtime":45}}
{"index":3,"chain_id":"abc123","class":"Orders::ProcessPayment","status":"success","metadata":{"runtime":892}}
{"index":4,"chain_id":"abc123","class":"Orders::ReserveInventory","status":"skipped","reason":"Digital order, no inventory needed"}
{"index":5,"chain_id":"abc123","class":"Orders::FinalizeOrder","status":"success","metadata":{"runtime":23}}
{"index":0,"chain_id":"abc123","class":"Orders::PlaceOrder","status":"success","metadata":{"runtime":985}}
```

Filter by `chain_id` and you see the entire lifecycle of that request. When something fails at 2 AM, you'll know exactly which task, with what data, and why.

## Handling Failures Gracefully

When a subtask fails, you can trace it:

```ruby
result = Orders::PlaceOrder.execute(user: user, cart_items: items)

if result.failed?
  if result.caused_failure
    culprit = result.caused_failure.task.class.name
    puts "Failed at: #{culprit}"
    puts "Reason: #{result.caused_failure.reason}"
  end
end
```

You can also use pattern matching for sophisticated error handling:

```ruby
case result
in { status: "failed", metadata: { code: :no_payment_method } }
  redirect_to payment_methods_path, alert: "Please add a payment method"
in { status: "failed", metadata: { code: :insufficient_inventory } }
  redirect_to cart_path, alert: "Some items are no longer available"
in { status: "failed", reason: msg }
  redirect_to checkout_path, alert: msg
in { status: "success" }
  redirect_to order_path(result.context.order)
end
```

## Using execute! for Controller Actions

Sometimes you want exceptions to bubble up. Use `execute!`:

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::PlaceOrder.execute!(
      user: current_user,
      cart_items: cart_params[:items]
    )

    redirect_to order_path(result.context.order),
      notice: "Order placed successfully!"

  rescue CMDx::FailFault => e
    flash[:error] = e.result.reason
    render :new, status: :unprocessable_entity

  rescue CMDx::SkipFault => e
    redirect_to cart_path, notice: e.result.reason
  end
end
```

The bang version raises `CMDx::FailFault` or `CMDx::SkipFault`, which carry the full result object for inspection.

## Nested Attributes for Complex Inputs

Real APIs send complex data. CMDx handles nested structures elegantly:

```ruby
class Orders::ProcessCheckout < CMDx::Task
  required :user_id, type: :integer

  required :shipping do
    required :address_line1, presence: true
    optional :address_line2
    required :city, presence: true
    required :postal_code, format: /\A\d{5}(-\d{4})?\z/
    required :country, inclusion: { in: ISO3166::Country.codes }
  end

  optional :billing do
    required :same_as_shipping, type: :boolean, default: true
    required :address_line1, presence: true, unless: :same_as_shipping?
    # ... more fields
  end

  def work
    # Access nested values directly
    context.shipping_address = {
      line1: address_line1,
      line2: address_line2,
      city: city,
      postal_code: postal_code,
      country: country
    }
  end

  private

  def same_as_shipping?
    context.dig(:billing, :same_as_shipping) == true
  end
end
```

Child requirements only apply when the parent is provided. If `billing` isn't passed, those validations don't run.

## Dry Run Mode for Previews

Want to show users what would happen without actually doing it?

```ruby
class Orders::PlaceOrder < CMDx::Task
  include CMDx::Workflow

  task Orders::ValidateCart
  task Orders::CalculateTotals
  task Orders::CheckInventory
  task Orders::CreateOrder, unless: :dry_run?
  task Orders::ProcessPayment, unless: :dry_run?
end
```

```ruby
# Preview the order
preview = Orders::PlaceOrder.execute(
  user: current_user,
  cart_items: items,
  dry_run: true
)

# Show the user what they'd pay
render json: {
  subtotal: preview.context.subtotal,
  tax: preview.context.tax,
  shipping: preview.context.shipping,
  total: preview.context.total,
  estimated_delivery: preview.context.delivery_date
}
```

The dry run validates and calculates everything without creating records or charging cards.

## Putting It All Together

Here's our complete order system:

```
app/tasks/orders/
├── validate_cart.rb
├── create_order.rb
├── process_payment.rb
├── reserve_inventory.rb
├── finalize_order.rb
└── place_order.rb          # The workflow
```

Each task is:
- **Single-purpose**: One job, done well
- **Self-documenting**: Attributes declare the interface
- **Observable**: Automatic logging with chain correlation
- **Testable**: No mocks needed, just pass data and check results
- **Reversible**: Rollbacks handle cleanup

The workflow is:
- **Declarative**: You can see the entire flow at a glance
- **Conditional**: Tasks run only when they should
- **Resilient**: Failures are handled gracefully
- **Traceable**: Every execution is logged with correlation IDs

## What We've Covered

We started with a messy 50-line service object and rebuilt it as a clean, maintainable system using CMDx:

1. **Tasks**: Single-purpose units of work with a consistent interface
2. **Context**: Explicit data flow between tasks
3. **Attributes**: Self-documenting interfaces with coercion and validation
4. **Interruptions**: `skip!` and `fail!` for controlled flow
5. **Outcomes**: Rich result objects with states and statuses
6. **Callbacks**: Side effects that react to execution outcomes
7. **Middlewares**: Cross-cutting concerns like transactions and tracing
8. **Workflows**: Declarative orchestration of complex processes
9. **Logging**: Automatic observability with chain correlation

This is how I build Rails applications now. The code is cleaner, the logs are useful, and when something breaks at 2 AM, I can trace exactly what happened.

Give CMDx a try on your next feature. Start with a single task, get comfortable with the pattern, then build up to workflows. You'll wonder how you ever lived without it.

Happy coding!

# Example

This comprehensive example demonstrates CMDx in a realistic e-commerce order processing scenario, showcasing parameter validation, hooks, error handling, and result processing.

## Table of Contents

- [Task Implementation](#task-implementation)
- [Controller Integration](#controller-integration)
- [Background Job Integration](#background-job-integration)

> [!NOTE]
> This example uses Rails conventions but CMDx works with any Ruby application framework.

## Task Implementation

```ruby
class ProcessOrderTask < CMDx::Task
  # Parameter validation with types and constraints
  required :order_id, :user_id, type: :integer

  # Nested parameter definitions
  required :billing_details do
    required :email, type: :string, format: { with: /@/ }
    required :address do
      required :street, :city, :postal_code, type: :string
      optional :apartment, type: :string
    end
  end

  required :shipping_details do
    required :method, type: :string, inclusion: { in: %w[standard express overnight] }
    optional :address, from: :billing_details
    optional :instructions, type: :string, length: { max: 500 }
  end

  # Optional parameters with contextual defaults
  optional :package do
    required :delivery_company,
      type: :string,
      default: -> { context.user.premium? ? "UPS" : "USPS" },
      inclusion: { in: %w[UPS FedEx USPS DHL] }
    optional :weight, :volume, type: :float, numeric: { min: 0 }
    optional :insurance, type: :boolean, default: false
  end

  optional :notifications do
    optional :email_enabled, type: :boolean, default: true
    optional :sms_enabled, type: :boolean, default: false
    optional :phone_number, type: :string,
      format: { with: /\A\d{10}\z/ },
      if: proc { context.notifications&.sms_enabled }
  end

  # Task configuration
  task_settings!(
    tags: ["orders", "payment"],
    logger: Rails.logger
  )

  # Lifecycle hooks
  before_execution :validate_business_rules
  before_validation :load_dependencies

  on_success :send_confirmations, :update_inventory
  on_failed :handle_failure, if: :critical_order?
  on_skipped :log_skip_reason

  def call
    if order_abandoned?
      skip!(
        reason: "Order abandoned - cart inactive for #{days_inactive} days",
        recoverable: days_inactive < 30
      )
    elsif inventory_unavailable?
      fail!(
        reason: "Items out of stock",
        out_of_stock_items: unavailable_items,
        error_code: "INVENTORY_UNAVAILABLE"
      )
    elsif payment_invalid?
      fail!(
        reason: "Payment method invalid or expired",
        retry_allowed: context.payment_method.retryable?,
        error_code: "PAYMENT_INVALID"
      )
    else
      process_payment
      fulfill_order
      schedule_delivery
    end
  end

  private

  def validate_business_rules
    fail!("Orders cannot be processed outside business hours") unless business_hours?
  end

  def load_dependencies
    context.user = User.find(user_id)
    context.order = Order.find(order_id)
    context.payment_method = context.user.payment_methods.active.first
  end

  def send_confirmations
    context.email_sent = send_email_notification if notifications.email_enabled
    context.sms_sent = send_sms_notification if notifications.sms_enabled
  end

  def update_inventory
    InventoryService.decrement_stock(context.order.items)
  end

  def handle_failure
    Rails.logger.error(
      "Critical order processing failed",
      order_id: context.order.id,
      error: result.metadata[:reason]
    )
    AlertService.notify_support(context.order, result.metadata)
  end

  def log_skip_reason
    Rails.logger.info("Order skipped: #{result.metadata[:reason]}")
  end

  # Business logic helpers
  def order_abandoned?
    context.order.last_activity < 7.days.ago
  end

  def inventory_unavailable?
    context.order.items.any? { |item| item.stock_quantity < item.quantity }
  end

  def payment_invalid?
    !context.payment_method&.valid? || context.payment_method&.expired?
  end

  def business_hours?
    Time.current.hour.between?(9, 17) && Time.current.weekday?
  end

  def critical_order?
    context.order.total > 1000 || context.user.premium?
  end

  def days_inactive
    (Time.current - context.order.last_activity).to_i / 1.day
  end

  def unavailable_items
    context.order.items.select { |item| item.stock_quantity < item.quantity }.pluck(:id)
  end

  def process_payment
    payment_result = ChargePaymentTask.call(
      payment_method: context.payment_method,
      amount: context.order.total,
      order_id: context.order.id
    )
    throw!(payment_result) if payment_result.failed?
    context.payment_confirmed = true
  end

  def fulfill_order
    fulfillment_result = FulfillOrderTask.call(
      order: context.order,
      shipping_details: shipping_details
    )
    throw!(fulfillment_result) if fulfillment_result.failed?
  end

  def schedule_delivery
    delivery_result = ScheduleDeliveryTask.call(
      order: context.order,
      method: shipping_details.method,
      company: package.delivery_company
    )

    context.tracking_number = delivery_result.context.tracking_number if delivery_result.success?
  end

  def send_email_notification
    EmailConfirmationTask.call(
      email: billing_details.email,
      order: context.order
    ).success?
  end

  def send_sms_notification
    SmsConfirmationTask.call(
      phone: notifications.phone_number,
      message: "Order ##{context.order.id} confirmed!"
    ).success?
  end
end
```

> [!TIP]
> Use contextual defaults with lambdas to make parameters dynamic based on the execution context.

## Controller Integration

> [!WARNING]
> Always handle all possible task outcomes: `success`, `failed`, and `skipped`.

```ruby
class OrdersController < ApplicationController
  def create
    result = ProcessOrderTask.call(order_params)

    case result.status
    when "success"
      flash[:success] = "Order ##{result.context.order.id} confirmed!"
      redirect_to order_path(result.context.order)
    when "skipped"
      handle_skipped_order(result)
    when "failed"
      handle_failed_order(result)
    end
  end

  def create_with_exceptions
    # Using call! for exception-based flow control
    result = ProcessOrderTask.call!(order_params)

    flash[:success] = "Order processed successfully!"
    redirect_to order_path(result.context.order)

  rescue CMDx::Failed => e
    handle_failed_order(e.result)
  rescue CMDx::Skipped => e
    handle_skipped_order(e.result)
  end

  private

  def order_params
    params.require(:order).permit(
      :order_id, :user_id,
      billing_details: [:email, address: [:street, :city, :postal_code, :apartment]],
      shipping_details: [:method, :instructions],
      package: [:delivery_company, :weight, :insurance],
      notifications: [:email_enabled, :sms_enabled, :phone_number]
    )
  end

  def handle_skipped_order(result)
    case result.metadata[:error_code]
    when "CART_ABANDONED"
      if result.metadata[:recoverable]
        flash[:warning] = "Cart saved for later due to inactivity"
        redirect_to cart_path
      else
        flash[:notice] = "Cart expired. Please create a new order"
        redirect_to new_order_path
      end
    else
      flash[:notice] = result.metadata[:reason]
      redirect_to orders_path
    end
  end

  def handle_failed_order(result)
    case result.metadata[:error_code]
    when "INVENTORY_UNAVAILABLE"
      flash[:error] = "Some items are out of stock"
      redirect_to edit_order_path(result.context.order)
    when "PAYMENT_INVALID"
      flash[:error] = "Payment method needs updating"
      redirect_to payment_methods_path
    else
      flash[:error] = "Order failed: #{result.metadata[:reason]}"
      render :new, status: :unprocessable_entity
    end
  end
end
```

## Background Job Integration

```ruby
class ProcessOrderJob < ApplicationJob
  queue_as :orders

  retry_on CMDx::Failed,
    wait: :exponentially_longer,
    attempts: 3,
    if: ->(job, exception) { exception.result.metadata[:retry_allowed] }

  def perform(order_id, user_id, **options)
    result = ProcessOrderTask.call!(
      order_id: order_id,
      user_id: user_id,
      **options
    )

    OrderMailer.processing_complete(result.context.order).deliver_now

  rescue CMDx::Skipped => e
    Rails.logger.info("Order processing skipped: #{e.result.metadata[:reason]}")
  rescue CMDx::Failed => e
    OrderMailer.processing_failed(order_id, e.result.metadata[:reason]).deliver_now
    raise # Re-raise to mark job as failed
  end
end
```

> [!NOTE]
> Use the `retry_allowed` metadata flag to control which failures should be retried in background jobs.

This example demonstrates CMDx's capabilities for building robust, monitorable business logic with comprehensive error handling and clear execution flows.

---

- **Prev:** [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
- **Next:** [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md)

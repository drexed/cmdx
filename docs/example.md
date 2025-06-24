# Example

This comprehensive example demonstrates the key features and patterns of CMDx tasks, showcasing parameter validation, hooks, error handling, and result processing in a realistic e-commerce order processing scenario.

## Task Implementation

```ruby
class ProcessOrderTask < CMDx::Task
  # Parameter validation with types and constraints
  required :order_id, type: :integer
  required :user_id, type: :integer

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
    optional :address, from: :billing_details  # Inherit from billing if not provided
    optional :instructions, type: :string, length: { max: 500 }
  end

  # Optional parameters with defaults and validation
  optional :package do
    required :delivery_company,
      type: :string,
      default: -> { context.user.premium? ? "UPS" : "USPS" },
      inclusion: { in: %w[UPS FedEx USPS DHL] }
    optional :weight, :volume, type: :float, numeric: { min: 0 }
    optional :insurance, type: :boolean, default: false
  end

  optional :notification_preferences do
    optional :email_updates, type: :boolean, default: true
    optional :sms_updates, type: :boolean, default: false
    optional :phone_number, type: :string,
      format: { with: /\A\d{10}\z/ },
      if: proc { context.notification_preferences&.sms_updates }
  end

  # Task configuration
  task_settings!(
    tags: ["orders", "payment", "fulfillment"],
    logger: Rails.logger
  )

  # Lifecycle hooks
  before_execution :validate_business_rules
  before_validation :load_dependencies
  after_validation :set_context_defaults

  on_executing :start_timing
  on_complete :record_metrics
  on_success :send_confirmations, :update_inventory
  on_failed :handle_failure, :alert_support, if: :critical_order?
  on_skipped :log_skip_reason

  def call
    # Business logic with multiple exit paths
    if order_abandoned?
      skip!(
        reason: "Cart abandoned due to inactivity",
        abandoned_at: context.order.last_activity,
        days_inactive: days_since_activity,
        recoverable: true
      )
    elsif items_out_of_stock?
      fail!(
        reason: "Items in cart are out of stock",
        out_of_stock_items: out_of_stock_item_ids,
        restock_date: estimated_restock_date,
        error_code: "INVENTORY_UNAVAILABLE"
      )
    elsif payment_method_invalid?
      fail!(
        reason: "Payment method validation failed",
        payment_errors: context.payment_method.errors.full_messages,
        retry_allowed: true,
        error_code: "PAYMENT_INVALID"
      )
    else
      # Main processing flow
      process_payment
      fulfill_order
      schedule_delivery
    end
  end

  private

  # Hook implementations
  def validate_business_rules
    unless business_hours?
      fail!("Orders cannot be processed outside business hours")
    end
  end

  def load_dependencies
    context.user = User.find(user_id)
    context.order = Order.find(order_id)
    context.payment_method = context.user.payment_methods.find(context.order.payment_method_id)
  end

  def set_context_defaults
    context.started_at = Time.current
    context.processing_priority = determine_priority
  end

  def start_timing
    context.processing_start = Time.current
  end

  def record_metrics
    MetricsService.record_order_processing(
      order_id: context.order.id,
      duration: Time.current - context.processing_start,
      status: result.status
    )
  end

  def send_confirmations
    # Only send confirmations on successful completion
    context.confirmation_sent = send_email_confirmation && send_sms_confirmation
  end

  def update_inventory
    InventoryService.update_stock_levels(context.order.items)
  end

  def handle_failure
    # Log detailed failure information
    Rails.logger.error(
      "Order processing failed",
      order_id: context.order.id,
      user_id: context.user.id,
      error: result.metadata[:reason],
      error_code: result.metadata[:error_code]
    )
  end

  def alert_support
    SupportAlertService.notify(
      alert_type: "critical_order_failure",
      order_value: context.order.total_value,
      customer_tier: context.user.tier,
      error_details: result.metadata
    )
  end

  def log_skip_reason
    Rails.logger.info(
      "Order processing skipped",
      order_id: context.order.id,
      reason: result.metadata[:reason],
      recoverable: result.metadata[:recoverable]
    )
  end

  # Business logic methods
  def order_abandoned?
    context.order.last_activity < 30.days.ago
  end

  def items_out_of_stock?
    context.order.items.any? { |item| item.stock_quantity < item.requested_quantity }
  end

  def payment_method_invalid?
    !context.payment_method.valid? || context.payment_method.expired?
  end

  def business_hours?
    Time.current.hour.between?(9, 17) && !weekend?
  end

  def weekend?
    Time.current.saturday? || Time.current.sunday?
  end

  def critical_order?
    context.order.total_value > 1000 || context.user.tier == "premium"
  end

  def days_since_activity
    (Time.current - context.order.last_activity).to_i / 1.day
  end

  def out_of_stock_item_ids
    context.order.items
      .select { |item| item.stock_quantity < item.requested_quantity }
      .map(&:id)
  end

  def estimated_restock_date
    InventoryService.estimated_restock_date(out_of_stock_item_ids)
  end

  def determine_priority
    return "high" if context.user.tier == "premium"
    return "high" if context.order.total_value > 500
    return "medium" if context.shipping_details.method == "express"
    "low"
  end

  def process_payment
    context.payment_result = ChargePaymentMethodTask.call(
      payment_method: context.payment_method,
      amount: context.order.total_amount,
      currency: context.order.currency,
      order_id: context.order.id
    )

    # Propagate payment failures
    throw!(context.payment_result) if context.payment_result.failed?
  end

  def fulfill_order
    context.fulfillment_result = FulfillOrderTask.call(
      order: context.order,
      shipping_details: shipping_details,
      package: package
    )

    throw!(context.fulfillment_result) if context.fulfillment_result.failed?
  end

  def schedule_delivery
    context.delivery_result = ScheduleDeliveryTask.call(
      order: context.order,
      shipping_method: shipping_details.method,
      delivery_company: package.delivery_company
    )

    # Continue even if delivery scheduling fails (can be retried later)
    if context.delivery_result.failed?
      Rails.logger.warn(
        "Delivery scheduling failed, will retry",
        order_id: context.order.id,
        error: context.delivery_result.metadata[:reason]
      )
    end
  end

  def send_email_confirmation
    return false unless notification_preferences.email_updates

    EmailConfirmationTask.call(
      email: billing_details.email,
      order: context.order,
      delivery_estimate: context.delivery_result&.context&.estimated_delivery
    ).success?
  end

  def send_sms_confirmation
    return true unless notification_preferences.sms_updates # Skip if SMS disabled

    SmsConfirmationTask.call(
      phone_number: notification_preferences.phone_number,
      order: context.order,
      tracking_number: context.delivery_result&.context&.tracking_number
    ).success?
  end
end
```

## Controller Integration

```ruby
class OrdersController < ApplicationController
  def create
    # Execute the task with comprehensive error handling
    result = ProcessOrderTask.call(order_params)

    # Handle different outcomes
    case result.status
    when "success"
      # Successful order processing
      flash[:success] = "Order ##{result.context.order.id} is on its way!"

      # Access rich context data
      if result.context.delivery_result&.success?
        flash[:info] = "Tracking number: #{result.context.delivery_result.context.tracking_number}"
      end

      redirect_to order_path(result.context.order)

    when "skipped"
      # Order was skipped (e.g., abandoned cart)
      handle_skipped_order(result)

    when "failed"
      # Order processing failed
      handle_failed_order(result)
    end
  end

  def create_with_bang
    # Using call! for exception-based error handling
    begin
      result = ProcessOrderTask.call!(order_params)

      # Will only reach here on success
      flash[:success] = "Order processed successfully!"
      redirect_to order_path(result.context.order)

    rescue CMDx::Failed => e
      # Handle failure exceptions
      handle_failed_order(e.result)

    rescue CMDx::Skipped => e
      # Handle skip exceptions (if configured to halt on skips)
      handle_skipped_order(e.result)
    end
  end

  private

  def order_params
    params.require(:order).permit(
      :order_id, :user_id,
      billing_details: [
        :email,
        address: [:street, :city, :postal_code, :apartment]
      ],
      shipping_details: [
        :method, :instructions,
        address: [:street, :city, :postal_code, :apartment]
      ],
      package: [:delivery_company, :weight, :volume, :insurance],
      notification_preferences: [:email_updates, :sms_updates, :phone_number]
    )
  end

  def handle_skipped_order(result)
    reason = result.metadata[:reason]

    case result.metadata[:error_code]
    when "CART_ABANDONED"
      if result.metadata[:recoverable]
        flash[:warning] = "Your cart was inactive. Items have been saved for later."
        redirect_to cart_recovery_path(result.context.order)
      else
        flash[:notice] = "Your cart has expired. Please start a new order."
        redirect_to new_order_path
      end
    else
      flash[:notice] = "Order processing was skipped: #{reason}"
      redirect_to orders_path
    end
  end

  def handle_failed_order(result)
    error_code = result.metadata[:error_code]
    reason = result.metadata[:reason]

    case error_code
    when "INVENTORY_UNAVAILABLE"
      flash[:error] = "Some items are out of stock. #{reason}"

      if result.metadata[:restock_date]
        flash[:info] = "Expected restock: #{result.metadata[:restock_date].strftime('%B %d, %Y')}"
      end

      redirect_to edit_order_path(result.context.order)

    when "PAYMENT_INVALID"
      if result.metadata[:retry_allowed]
        flash[:error] = "Payment failed: #{reason}. Please update your payment method."
        redirect_to edit_payment_method_path
      else
        flash[:error] = "Payment could not be processed. Please contact support."
        redirect_to support_path
      end

    else
      # Generic failure handling
      flash[:error] = "Order processing failed: #{reason}"

      # Log for investigation
      Rails.logger.error(
        "Unhandled order processing failure",
        order_id: result.context.order&.id,
        error_code: error_code,
        user_id: current_user.id,
        metadata: result.metadata
      )

      render :new, status: :unprocessable_entity
    end
  end
end
```

## Background Job Integration

```ruby
class ProcessOrderJob < ApplicationJob
  queue_as :orders

  retry_on CMDx::Failed, wait: :exponentially_longer, attempts: 3 do |job, exception|
    # Handle retryable failures
    if exception.result.metadata[:retry_allowed]
      Rails.logger.info("Retrying order processing", order_id: job.arguments.first)
    else
      # Don't retry non-retryable failures
      raise exception
    end
  end

  def perform(order_id, user_id, **options)
    result = ProcessOrderTask.call!(
      order_id: order_id,
      user_id: user_id,
      **options
    )

    # Successful processing
    OrderMailer.processing_complete(result.context.order).deliver_now

  rescue CMDx::Skipped => e
    # Handle skipped processing in background
    Rails.logger.info(
      "Background order processing skipped",
      order_id: order_id,
      reason: e.result.metadata[:reason]
    )

  rescue CMDx::Failed => e
    # Handle final failure after retries
    OrderMailer.processing_failed(
      order_id: order_id,
      error: e.result.metadata[:reason]
    ).deliver_now

    # Re-raise to mark job as failed
    raise
  end
end
```

## Result Analysis and Monitoring

```ruby
class OrderAnalyticsService
  def self.analyze_processing_results(from_date, to_date)
    # Collect processing results from logs or database
    results = ProcessOrderTask.where(created_at: from_date..to_date)

    results.each do |result|
      analyze_result(result)
    end
  end

  def self.analyze_result(result)
    # Success rate analysis
    puts "Task: #{result.task.class.name}"
    puts "Status: #{result.status}"
    puts "Runtime: #{result.runtime}s"
    puts "Outcome: #{result.outcome}"

    # Detailed analysis based on outcome
    case result.status
    when "success"
      analyze_success_metrics(result)
    when "skipped"
      analyze_skip_patterns(result)
    when "failed"
      analyze_failure_patterns(result)
    end

    # Performance analysis
    analyze_performance(result)
  end

  def self.analyze_success_metrics(result)
    puts "✓ Success Metrics:"
    puts "  - Order Value: $#{result.context.order.total_value}"
    puts "  - Confirmation Sent: #{result.context.confirmation_sent}"
    puts "  - Payment Method: #{result.context.payment_method.type}"
    puts "  - Delivery Company: #{result.context.package.delivery_company}"
  end

  def self.analyze_skip_patterns(result)
    puts "⏭ Skip Analysis:"
    puts "  - Reason: #{result.metadata[:reason]}"
    puts "  - Recoverable: #{result.metadata[:recoverable]}"
    puts "  - Days Inactive: #{result.metadata[:days_inactive]}"

    # Track skip trends
    SkipTrendTracker.record(
      reason: result.metadata[:reason],
      order_value: result.context.order&.total_value,
      user_tier: result.context.user&.tier
    )
  end

  def self.analyze_failure_patterns(result)
    puts "✗ Failure Analysis:"
    puts "  - Error Code: #{result.metadata[:error_code]}"
    puts "  - Reason: #{result.metadata[:reason]}"
    puts "  - Retryable: #{result.metadata[:retry_allowed]}"

    # Failure chain analysis
    if result.caused_failure?
      puts "  - Original Failure: Yes"
    elsif original_failure = result.caused_failure
      puts "  - Original Failure: #{original_failure.task.class.name}"
      puts "  - Original Reason: #{original_failure.metadata[:reason]}"
    end

    # Alert on critical failures
    if result.metadata[:error_code] == "INVENTORY_UNAVAILABLE"
      InventoryAlertService.notify(result.metadata[:out_of_stock_items])
    end
  end

  def self.analyze_performance(result)
    puts "📊 Performance Metrics:"
    puts "  - Total Runtime: #{result.runtime}s"
    puts "  - Task ID: #{result.task.id}"
    puts "  - Run ID: #{result.run.id}"
    puts "  - Tags: #{result.task.task_setting(:tags)&.join(', ')}"

    # Performance alerting
    if result.runtime > 30 # seconds
      PerformanceAlertService.notify(
        task: result.task.class.name,
        runtime: result.runtime,
        order_id: result.context.order&.id
      )
    end
  end
end
```

## Testing Examples

```ruby
RSpec.describe ProcessOrderTask do
  let(:valid_params) do
    {
      order_id: order.id,
      user_id: user.id,
      billing_details: {
        email: "customer@example.com",
        address: {
          street: "123 Main St",
          city: "Anytown",
          postal_code: "12345"
        }
      },
      shipping_details: {
        method: "standard"
      }
    }
  end

  describe "successful processing" do
    it "processes order successfully" do
      result = ProcessOrderTask.call(valid_params)

      expect(result).to be_success
      expect(result).to be_good
      expect(result.context.order).to be_present
      expect(result.context.payment_result).to be_success
      expect(result.context.confirmation_sent).to be true
      expect(result.runtime).to be > 0
    end
  end

  describe "skip scenarios" do
    context "when cart is abandoned" do
      before do
        order.update!(last_activity: 31.days.ago)
      end

      it "skips processing with appropriate metadata" do
        result = ProcessOrderTask.call(valid_params)

        expect(result).to be_skipped
        expect(result).to be_good  # Skips are "good" outcomes
        expect(result).to be_bad   # But also "bad" (not success)
        expect(result.metadata[:reason]).to include("abandoned")
        expect(result.metadata[:recoverable]).to be true
        expect(result.metadata[:days_inactive]).to eq 31
      end
    end
  end

  describe "failure scenarios" do
    context "when items are out of stock" do
      before do
        order.items.first.update!(stock_quantity: 0)
      end

      it "fails with detailed error information" do
        result = ProcessOrderTask.call(valid_params)

        expect(result).to be_failed
        expect(result).to be_bad
        expect(result).not_to be_good
        expect(result.metadata[:error_code]).to eq "INVENTORY_UNAVAILABLE"
        expect(result.metadata[:out_of_stock_items]).to include(order.items.first.id)
        expect(result.metadata[:restock_date]).to be_present
      end
    end
  end

  describe "hook execution" do
    it "executes hooks in correct order" do
      allow(MetricsService).to receive(:record_order_processing)

      result = ProcessOrderTask.call(valid_params)

      expect(MetricsService).to have_received(:record_order_processing).with(
        order_id: order.id,
        duration: be_a(Numeric),
        status: "success"
      )
    end
  end

  describe "exception handling with call!" do
    context "when order processing fails" do
      before do
        order.items.first.update!(stock_quantity: 0)
      end

      it "raises CMDx::Failed exception" do
        expect {
          ProcessOrderTask.call!(valid_params)
        }.to raise_error(CMDx::Failed) do |exception|
          expect(exception.result.metadata[:error_code]).to eq "INVENTORY_UNAVAILABLE"
          expect(exception.context.order).to eq order
        end
      end
    end
  end
end
```

This comprehensive example demonstrates:

- **Parameter Validation**: Complex nested parameters with validation rules
- **Hooks**: Lifecycle management with conditional execution
- **Error Handling**: Detailed skip and failure scenarios with metadata
- **Result Processing**: Comprehensive outcome handling in controllers
- **Background Jobs**: Integration with Rails job processing
- **Monitoring**: Result analysis and performance tracking
- **Testing**: Complete test coverage of all scenarios

The example showcases CMDx's power in building robust, maintainable business logic with comprehensive error handling and monitoring capabilities.

---

- **Prev:** [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
- **Next:** [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md)

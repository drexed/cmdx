# frozen_string_literal: true

module CMDx

  ##
  # Skipped is a specific fault type raised when a task execution is intentionally
  # skipped via the `skip!` method. This represents a controlled interruption where
  # the task determines that execution is not necessary or appropriate under the
  # current conditions.
  #
  # Skipped faults are typically used for:
  # - Conditional logic where certain conditions make execution unnecessary
  # - Early returns when prerequisites are not met
  # - Business logic that determines the operation is redundant
  # - Graceful handling of edge cases that don't constitute errors
  #
  # @example Basic skip usage
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #
  #     def call
  #       context.order = Order.find(order_id)
  #       skip!(reason: "Order already processed") if context.order.processed?
  #
  #       context.order.process!
  #     end
  #   end
  #
  #   # Non-bang call returns result
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.skipped? #=> true
  #   result.metadata[:reason] #=> "Order already processed"
  #
  #   # Bang call raises exception
  #   begin
  #     ProcessOrderTask.call!(order_id: 123)
  #   rescue CMDx::Skipped => e
  #     puts "Skipped: #{e.message}"
  #   end
  #
  # @example Conditional skip logic
  #   class SendNotificationTask < CMDx::Task
  #     required :user_id, type: :integer
  #     optional :force, type: :boolean, default: false
  #
  #     def call
  #       context.user = User.find(user_id)
  #
  #       unless force || context.user.notifications_enabled?
  #         skip!(reason: "User has notifications disabled")
  #       end
  #
  #       NotificationService.send(context.user)
  #     end
  #   end
  #
  # @example Handling skipped tasks in workflows
  #   begin
  #     OrderProcessingWorkflow.call!(orders: orders)
  #   rescue CMDx::Skipped => e
  #     # Log skipped operations but continue processing
  #     logger.info "Skipped processing: #{e.message}"
  #   end
  #
  # @see Fault Base fault class with advanced matching capabilities
  # @see Failed Failed fault type for error conditions
  # @see Result#skip! Method for triggering skipped faults
  # @since 1.0.0
  Skipped = Class.new(Fault)

  ##
  # Failed is a specific fault type raised when a task execution encounters an
  # error condition via the `fail!` method. This represents a controlled failure
  # where the task explicitly determines that execution cannot continue successfully.
  #
  # Failed faults are typically used for:
  # - Validation errors that prevent successful execution
  # - Business rule violations that constitute failures
  # - Resource unavailability or constraint violations
  # - Explicit error conditions that require attention
  #
  # @example Basic failure usage
  #   class ProcessPaymentTask < CMDx::Task
  #     required :payment_amount, type: :float
  #     required :payment_method, type: :string
  #
  #     def call
  #       unless payment_amount > 0
  #         fail!(reason: "Payment amount must be positive", code: "INVALID_AMOUNT")
  #       end
  #
  #       unless valid_payment_method?
  #         fail!(reason: "Invalid payment method", code: "INVALID_METHOD")
  #       end
  #
  #       process_payment
  #     end
  #   end
  #
  #   # Non-bang call returns result
  #   result = ProcessPaymentTask.call(payment_amount: -10, payment_method: "card")
  #   result.failed? #=> true
  #   result.metadata[:reason] #=> "Payment amount must be positive"
  #   result.metadata[:code] #=> "INVALID_AMOUNT"
  #
  #   # Bang call raises exception
  #   begin
  #     ProcessPaymentTask.call!(payment_amount: -10, payment_method: "card")
  #   rescue CMDx::Failed => e
  #     puts "Failed: #{e.message}"
  #     puts "Error code: #{e.result.metadata[:code]}"
  #   end
  #
  # @example Validation failure with detailed metadata
  #   class CreateUserTask < CMDx::Task
  #     required :email, type: :string
  #     required :password, type: :string
  #
  #     def call
  #       if User.exists?(email: email)
  #         fail!(
  #           "Email already exists",
  #           code: "EMAIL_EXISTS",
  #           field: "email",
  #           suggested_action: "Use different email or login instead"
  #         )
  #       end
  #
  #       context.user = User.create!(email: email, password: password)
  #     end
  #   end
  #
  # @example Handling specific failure types
  #   begin
  #     ProcessOrderTask.call!(order_id: 123)
  #   rescue CMDx::Failed.matches? { |f| f.result.metadata[:code] == "PAYMENT_DECLINED" } => e
  #     # Handle payment failures specifically
  #     retry_with_backup_payment_method(e.context)
  #   rescue CMDx::Failed => e
  #     # Handle all other failures
  #     log_failure_and_notify_support(e)
  #   end
  #
  # @example Failure propagation in complex workflows
  #   class OrderFulfillmentTask < CMDx::Task
  #     def call
  #       payment_result = ProcessPaymentTask.call(context)
  #
  #       if payment_result.failed?
  #         fail!(
  #           "Cannot fulfill order due to payment failure",
  #           code: "PAYMENT_REQUIRED",
  #           original_error: payment_result.metadata
  #         )
  #       end
  #
  #       fulfill_order
  #     end
  #   end
  #
  # @see Fault Base fault class with advanced matching capabilities
  # @see Skipped Skipped fault type for conditional interruptions
  # @see Result#fail! Method for triggering failed faults
  # @since 1.0.0
  Failed = Class.new(Fault)

end

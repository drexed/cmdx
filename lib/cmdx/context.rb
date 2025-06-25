# frozen_string_literal: true

module CMDx
  ##
  # Context provides a flexible parameter storage and data passing mechanism for CMDx tasks.
  # It extends LazyStruct to offer dynamic attribute access with both hash-style and method-style
  # syntax, serving as the primary interface for task input parameters and inter-task communication.
  #
  # Context objects act as the data container for task execution, holding input parameters,
  # intermediate results, and any data that needs to be shared between tasks. They support
  # dynamic attribute assignment and provide a convenient API for data manipulation throughout
  # the task execution lifecycle.
  #
  #
  # ## Usage Patterns
  #
  # Context is typically used in three main scenarios:
  # 1. **Parameter Input**: Passing initial data to tasks
  # 2. **Data Storage**: Storing intermediate results during task execution
  # 3. **Task Communication**: Sharing data between multiple tasks
  #
  # @example Basic parameter input
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #     optional :notify_customer, type: :boolean, default: true
  #
  #     def call
  #       context.order = Order.find(order_id)
  #       context.processed_at = Time.current
  #
  #       if notify_customer
  #         context.notification_sent = send_notification
  #       end
  #     end
  #   end
  #
  #   result = ProcessOrderTask.call(order_id: 123, notify_customer: false)
  #   result.context.order         #=> <Order id: 123>
  #   result.context.processed_at  #=> 2023-01-01 12:00:00 UTC
  #   result.context.notification_sent #=> nil
  #
  # @example Dynamic attribute assignment
  #   class DataProcessingTask < CMDx::Task
  #     required :input_data, type: :hash
  #
  #     def call
  #       # Method-style assignment
  #       context.processed_data = transform(input_data)
  #       context.validation_errors = validate(context.processed_data)
  #
  #       # Hash-style assignment
  #       context[:metadata] = { processed_at: Time.current }
  #       context["summary"] = generate_summary
  #
  #       # Batch assignment
  #       context.merge!(
  #         status: "complete",
  #         record_count: context.processed_data.size
  #       )
  #     end
  #   end
  #
  # @example Inter-task communication
  #   class OrderProcessingBatch < CMDx::Batch
  #     def call
  #       # First task sets up context
  #       ValidateOrderTask.call(context)
  #
  #       # Subsequent tasks use and modify context
  #       ProcessPaymentTask.call(context)
  #       UpdateInventoryTask.call(context)
  #       SendConfirmationTask.call(context)
  #     end
  #   end
  #
  #   # Initial context with order data
  #   result = OrderProcessingBatch.call(
  #     order_id: 123,
  #     payment_method: "credit_card",
  #     customer_email: "customer@example.com"
  #   )
  #
  #   # Context accumulates data from all tasks
  #   result.context.order           #=> <Order> (from ValidateOrderTask)
  #   result.context.payment_result  #=> <Payment> (from ProcessPaymentTask)
  #   result.context.inventory_updated #=> true (from UpdateInventoryTask)
  #   result.context.confirmation_sent #=> true (from SendConfirmationTask)
  #
  # @example Context passing between tasks
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #
  #     def call
  #       context.order = Order.find(order_id)
  #
  #       # Pass context to subtasks
  #       payment_result = ProcessPaymentTask.call(context)
  #       email_result = SendEmailTask.call(context)
  #
  #       # Results maintain context continuity
  #       context.payment_processed = payment_result.success?
  #       context.email_sent = email_result.success?
  #     end
  #   end
  #
  #   # After execution, context contains accumulated data
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.context.order              #=> <Order>
  #   result.context.payment_processed  #=> true
  #   result.context.email_sent         #=> true
  #
  # @example Context with nested data structures
  #   class AnalyticsTask < CMDx::Task
  #     required :user_id, type: :integer
  #
  #     def call
  #       context.user = User.find(user_id)
  #       context.analytics = {
  #         page_views: calculate_page_views,
  #         session_duration: calculate_session_duration,
  #         conversion_rate: calculate_conversion_rate
  #       }
  #
  #       # Access nested data
  #       context.dig(:analytics, :page_views)  #=> 150
  #
  #       # Add more nested data
  #       context.analytics[:last_login] = context.user.last_login
  #     end
  #   end
  #
  # @see LazyStruct Base class providing dynamic attribute functionality
  # @see Task Task base class that uses Context for parameter storage
  # @see Run Run execution context that Context belongs to
  # @see Parameter Parameter definitions that populate Context
  # @since 0.6.0
  class Context < LazyStruct

    ##
    # @!attribute [r] run
    #   @return [Run] the execution run that this context belongs to
    attr_reader :run

    ##
    # Builds a Context instance from the given input, with intelligent handling
    # of existing Context objects to avoid unnecessary object creation.
    #
    # This factory method provides optimized Context creation by:
    # - Returning existing Context objects if they're unfrozen (reusable)
    # - Creating new Context objects for frozen contexts (immutable)
    # - Converting hash-like objects into new Context instances
    #
    # @param context [Hash, Context, #to_h] input data for context creation
    # @return [Context] a Context instance ready for task execution
    #
    # @example Creating context from hash
    #   context = Context.build(name: "John", age: 30)
    #   context.name  #=> "John"
    #   context.age   #=> 30
    #
    # @example Reusing unfrozen context
    #   original = Context.build(data: "test")
    #   reused = Context.build(original)
    #   original.object_id == reused.object_id  #=> true
    #
    # @example Creating new context from frozen context
    #   original = Context.build(data: "test")
    #   original.freeze
    #   new_context = Context.build(original)
    #   original.object_id == new_context.object_id  #=> false
    #
    # @example Converting ActionController::Parameters
    #   # In Rails controllers
    #   params = ActionController::Parameters.new(user: { name: "John" })
    #   context = Context.build(params.permit(:user))
    #   context.user  #=> { name: "John" }
    #
    # @example Task execution with built context
    #   # CMDx automatically uses Context.build for task parameters
    #   result = ProcessOrderTask.call(order_id: 123, priority: "high")
    #   # Equivalent to:
    #   # context = Context.build(order_id: 123, priority: "high")
    #   # ProcessOrderTask.new(context).call
    def self.build(context = {})
      return context if context.is_a?(self) && !context.frozen?

      new(context)
    end

  end
end

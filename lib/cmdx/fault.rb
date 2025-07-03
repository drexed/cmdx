# frozen_string_literal: true

module CMDx
  ##
  # Fault serves as the base exception class for task execution interruptions in CMDx.
  # It provides a structured way to halt task execution with specific reasons and metadata,
  # while offering advanced exception matching capabilities for precise error handling.
  #
  # Faults are automatically raised when using the bang `call!` method on tasks that
  # encounter `skip!` or `fail!` conditions. They carry the full context of the
  # interrupted task, including the result object with its metadata and execution state.
  #
  #
  # ## Fault Types
  #
  # CMDx provides two primary fault types:
  # - **CMDx::Skipped**: Raised when a task is skipped via `skip!`
  # - **CMDx::Failed**: Raised when a task fails via `fail!`
  #
  # ## Exception Handling Patterns
  #
  # Faults support multiple rescue patterns for flexible error handling:
  # - Standard rescue by fault type
  # - Task-specific matching with `for?`
  # - Custom matching with `matches?`
  #
  # @example Basic fault handling
  #   begin
  #     ProcessOrderTask.call!(order_id: 123)
  #   rescue CMDx::Skipped => e
  #     logger.info "Task skipped: #{e.message}"
  #     e.result.metadata[:reason] #=> "Order already processed"
  #   rescue CMDx::Failed => e
  #     logger.error "Task failed: #{e.message}"
  #     e.task.class.name #=> "ProcessOrderTask"
  #   end
  #
  # @example Task-specific fault handling
  #   begin
  #     OrderProcessingWorkflow.call!(orders: orders)
  #   rescue CMDx::Fault.for?(ProcessOrderTask, ValidateOrderTask) => e
  #     # Handle faults only from specific task types
  #     retry_order_processing(e.context.order_id)
  #   end
  #
  # @example Advanced fault matching
  #   begin
  #     ProcessOrderTask.call!(order_id: 123)
  #   rescue CMDx::Fault.matches? { |f| f.result.metadata[:code] == "INVENTORY_DEPLETED" } => e
  #     # Handle specific fault conditions
  #     schedule_restock_notification(e.context.order)
  #   end
  #
  # @example Accessing fault context
  #   begin
  #     ProcessOrderTask.call!(order_id: 123)
  #   rescue CMDx::Fault => e
  #     e.result.status           #=> "failed" or "skipped"
  #     e.result.metadata[:reason] #=> "Insufficient inventory"
  #     e.task.id                 #=> Task instance UUID
  #     e.context.order_id        #=> 123
  #     e.chain.id                  #=> Chain instance UUID
  #   end
  #
  # @example Fault propagation with throw!
  #   class ProcessOrderTask < CMDx::Task
  #     def call
  #       validation_result = ValidateOrderTask.call(context)
  #       throw!(validation_result) if validation_result.failed?
  #
  #       # This will raise CMDx::Failed with validation task's metadata
  #     end
  #   end
  #
  # @see Result Result object containing fault details
  # @see Task Task execution methods (call vs call!)
  # @see CMDx::Skipped Specific fault type for skipped tasks
  # @see CMDx::Failed Specific fault type for failed tasks
  # @since 1.0.0
  class Fault < Error

    __cmdx_attr_delegator :task, :chain, :context,
                          to: :result

    ##
    # @!attribute [r] result
    #   @return [Result] the result object that caused this fault
    attr_reader :result

    ##
    # Initializes a new Fault with the given result object.
    # The fault message is derived from the result's metadata reason or falls back
    # to a localized default message.
    #
    # @param result [Result] the result object containing fault details
    #
    # @example Creating a fault from a failed result
    #   result = ProcessOrderTask.call(order_id: 999) # Non-existent order
    #   fault = Fault.new(result)
    #   fault.message #=> "Order not found"
    #   fault.result  #=> <Result status: "failed">
    #
    # @example Fault with I18n message
    #   # With custom locale configuration
    #   fault = Fault.new(result)
    #   fault.message #=> Localized message from I18n
    def initialize(result)
      @result = result
      super(result.metadata[:reason] || I18n.t("cmdx.faults.unspecified", default: "no reason given"))
    end

    class << self

      ##
      # Builds a specific fault type based on the result's status.
      # Dynamically creates the appropriate fault subclass (Skipped, Failed, etc.)
      # based on the result's current status.
      #
      # @param result [Result] the result object to build a fault from
      # @return [Fault] a fault instance of the appropriate subclass
      #
      # @example Building a skipped fault
      #   result = MyTask.call(param: "value")
      #   result.skip!(reason: "Not needed")
      #   fault = Fault.build(result)
      #   fault.class #=> CMDx::Skipped
      #
      # @example Building a failed fault
      #   result = MyTask.call(param: "invalid")
      #   result.fail!(reason: "Validation error")
      #   fault = Fault.build(result)
      #   fault.class #=> CMDx::Failed
      def build(result)
        fault = CMDx.const_get(result.status.capitalize)
        fault.new(result)
      end

      ##
      # Creates a fault matcher that only matches faults from specific task classes.
      # This enables precise exception handling based on the task type that caused the fault.
      #
      # @param tasks [Array<Class>] task classes to match against
      # @return [Class] a temporary fault class with custom matching logic
      #
      # @example Matching specific task types
      #   begin
      #     OrderWorkflow.call!(orders: orders)
      #   rescue CMDx::Fault.for?(ProcessOrderTask, ValidateOrderTask) => e
      #     # Only handle faults from these specific task types
      #     handle_order_processing_error(e)
      #   end
      #
      # @example Multiple task matching
      #   payment_tasks = [ProcessPaymentTask, ValidateCardTask, ChargeCardTask]
      #   begin
      #     PaymentWorkflow.call!(payment_data: data)
      #   rescue CMDx::Failed.for?(*payment_tasks) => e
      #     # Handle failures from any payment-related task
      #     process_payment_failure(e)
      #   end
      def for?(*tasks)
        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      ##
      # Creates a fault matcher with custom matching logic via a block.
      # This enables sophisticated fault matching based on any aspect of the fault,
      # including result metadata, task state, or context values.
      #
      # @param block [Proc] block that receives the fault and returns true/false for matching
      # @return [Class] a temporary fault class with custom matching logic
      # @raise [ArgumentError] if no block is provided
      #
      # @example Matching by error code
      #   begin
      #     ProcessOrderTask.call!(order_id: 123)
      #   rescue CMDx::Fault.matches? { |f| f.result.metadata[:error_code] == "PAYMENT_DECLINED" } => e
      #     # Handle specific payment errors
      #     retry_with_different_payment_method(e.context)
      #   end
      #
      # @example Matching by context values
      #   begin
      #     ProcessOrderTask.call!(order_id: 123)
      #   rescue CMDx::Fault.matches? { |f| f.context.order_value > 1000 } => e
      #     # Handle high-value order failures differently
      #     escalate_to_manager(e)
      #   end
      #
      # @example Complex matching logic
      #   begin
      #     WorkflowProcessor.call!(items: items)
      #   rescue CMDx::Fault.matches? { |f|
      #     f.result.failed? &&
      #     f.result.metadata[:reason]&.include?("timeout") &&
      #     f.chain.results.count(&:failed?) < 3
      #   } => e
      #     # Retry if it's a timeout with fewer than 3 failures in the chain
      #     retry_with_longer_timeout(e)
      #   end
      def matches?(&block)
        raise ArgumentError, "block required" unless block_given?

        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @block.call(other)
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@block, block) }
      end

    end

  end
end

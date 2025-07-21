# frozen_string_literal: true

module CMDx
  # Base fault class for handling task execution failures and interruptions.
  #
  # Faults are exceptions raised when tasks encounter specific execution states
  # that prevent normal completion. Unlike regular exceptions, faults carry
  # rich context information including the task result, execution chain, and
  # contextual data that led to the fault condition. Faults can be caught and
  # handled based on specific task types or custom matching criteria.
  class Fault < Error

    cmdx_attr_delegator :task, :chain, :context,
                        to: :result

    # @return [CMDx::Result] the result object that caused this fault
    attr_reader :result

    # Creates a new fault instance from a task execution result.
    #
    # @param result [CMDx::Result] the task result that caused the fault
    #
    # @return [CMDx::Fault] the newly created fault instance
    #
    # @example Create fault from failed task result
    #   result = SomeTask.call(invalid_data: true)
    #   fault = CMDx::Fault.new(result)
    #   fault.task #=> SomeTask instance
    def initialize(result)
      @result = result
      super(result.metadata[:reason] || I18n.t("cmdx.faults.unspecified", default: "no reason given"))
    end

    class << self

      # Builds a specific fault type based on the result's status.
      #
      # Creates an instance of the appropriate fault subclass (Skipped, Failed, etc.)
      # by capitalizing the result status and looking up the corresponding fault class.
      # This provides dynamic fault creation based on task execution outcomes.
      #
      # @param result [CMDx::Result] the task result to build a fault from
      #
      # @return [CMDx::Fault] an instance of the appropriate fault subclass
      #
      # @raise [NameError] if no fault class exists for the result status
      #
      # @example Build fault from skipped task result
      #   result = SomeTask.call # result.status is :skipped
      #   fault = CMDx::Fault.build(result)
      #   fault.class #=> CMDx::Skipped
      #
      # @example Build fault from failed task result
      #   result = SomeTask.call # result.status is :failed
      #   fault = CMDx::Fault.build(result)
      #   fault.class #=> CMDx::Failed
      def build(result)
        fault = CMDx.const_get(result.status.capitalize)
        fault.new(result)
      end

      # Creates a fault matcher that matches faults from specific task classes.
      #
      # Returns a dynamically created fault class that can be used in rescue blocks
      # to catch faults only when they originate from specific task types. This enables
      # selective fault handling based on the task that generated the fault.
      #
      # @param tasks [Array<Class>] one or more task classes to match against
      #
      # @return [Class] a fault matcher class that responds to case equality
      #
      # @example Catch faults from specific task types
      #   begin
      #     PaymentTask.call!
      #   rescue CMDx::Fault.for?(PaymentTask, RefundTask) => e
      #     puts "Payment operation failed: #{e.message}"
      #   end
      #
      # @example Match faults from multiple task types
      #   UserTaskFaults = CMDx::Fault.for?(CreateUserTask, UpdateUserTask, DeleteUserTask)
      #
      #   begin
      #     workflow.call!
      #   rescue CMDx::Fault.for?(CreateUserTask, UpdateUserTask, DeleteUserTask) => e
      #     handle_user_operation_failure(e)
      #   end
      def for?(*tasks)
        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      # Creates a fault matcher using a custom block for matching criteria.
      #
      # Returns a dynamically created fault class that uses the provided block
      # to determine if a fault should be matched. The block receives the fault
      # instance and should return true if the fault matches the desired criteria.
      # This enables custom fault handling logic beyond simple task type matching.
      #
      # @param block [Proc] a block that receives a fault and returns boolean
      #
      # @return [Class] a fault matcher class that responds to case equality
      #
      # @raise [ArgumentError] if no block is provided
      #
      # @example Match faults by custom criteria
      #   begin
      #     LongRunningTask.call!
      #   rescue CMDx::Fault.matches? { |fault| fault.context[:timeout_exceeded] } => e
      #     puts "Task timed out: #{e.message}"
      #   end
      #
      # @example Match faults by metadata content
      #   ValidationFault = CMDx::Fault.matches? { |fault| fault.result.metadata[:type] == "validation_error" }
      #
      #   begin
      #     ValidateUserTask.call!
      #   rescue ValidationFault => e
      #     display_validation_errors(e.result.errors)
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

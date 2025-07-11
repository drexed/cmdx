# frozen_string_literal: true

module CMDx
  # Exception class for task execution faults with result context.
  #
  # Fault provides a specialized exception that carries task execution context
  # including the failed result, task instance, and execution chain. It serves
  # as the base class for specific fault types and provides factory methods
  # for creating fault instances and conditional fault matchers.
  class Fault < Error

    cmdx_attr_delegator :task, :chain, :context,
                        to: :result

    # Creates a new fault instance with the given result context.
    #
    # The fault message is derived from the result's metadata reason or falls
    # back to a default internationalized message if no reason is provided.
    #
    # @param result [CMDx::Result] the failed task result that caused this fault
    #
    # @return [Fault] the newly created fault instance
    #
    # @example Create a fault from a failed result
    #   result = CMDx::Result.new(task)
    #   result.fail!(reason: "Database connection failed")
    #   fault = CMDx::Fault.new(result)
    #   fault.message # => "Database connection failed"
    def initialize(result)
      @result = result
      super(result.metadata[:reason] || I18n.t("cmdx.faults.unspecified", default: "no reason given"))
    end

    class << self

      # Builds a fault instance based on the result's status.
      #
      # Creates a specific fault subclass by capitalizing the result status
      # and looking up the corresponding fault class constant. This allows
      # for status-specific fault types like Failed, Skipped, etc.
      #
      # @param result [CMDx::Result] the failed task result
      #
      # @return [Fault] a fault instance of the appropriate subclass
      #
      # @raise [NameError] if no fault class exists for the result status
      #
      # @example Build a fault for a failed result
      #   result = CMDx::Result.new(task)
      #   result.fail!
      #   fault = CMDx::Fault.build(result)
      #   fault.class # => CMDx::Failed
      def build(result)
        fault = CMDx.const_get(result.status.capitalize)
        fault.new(result)
      end

      # Creates a fault matcher that matches faults from specific task classes.
      #
      # Returns a temporary fault class that can be used in rescue clauses
      # to catch faults only from the specified task types. The matcher uses
      # the === operator to check if the fault's task is an instance of any
      # of the given task classes.
      #
      # @param tasks [Array<Class>] task classes to match against
      #
      # @return [Class] a temporary fault class that matches the specified tasks
      #
      # @example Match faults from specific task classes
      #   rescue CMDx::Fault.for?(UserCreateTask, UserUpdateTask) => fault
      #     # Handle faults only from user-related tasks
      #     logger.error "User operation failed: #{fault.message}"
      #   end
      def for?(*tasks)
        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      # Creates a fault matcher that matches faults based on a custom condition.
      #
      # Returns a temporary fault class that can be used in rescue clauses
      # to catch faults that satisfy the given block condition. The matcher
      # uses the === operator to evaluate the block against the fault instance.
      #
      # @param block [Proc] the condition block to evaluate against fault instances
      #
      # @return [Class] a temporary fault class that matches the block condition
      #
      # @raise [ArgumentError] if no block is provided
      #
      # @example Match faults based on custom condition
      #   rescue CMDx::Fault.matches? { |f| f.task.context.user_id == current_user.id } => fault
      #     # Handle faults only for current user's operations
      #     notify_user_of_failure(fault)
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

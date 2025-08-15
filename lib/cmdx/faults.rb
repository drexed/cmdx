# frozen_string_literal: true

module CMDx

  # Base fault class for handling task execution failures and interruptions.
  #
  # Faults represent error conditions that occur during task execution, providing
  # a structured way to handle and categorize different types of failures.
  # Each fault contains a reference to the result object that caused the fault.
  class Fault < Error

    # @return [Result] the result object that caused this fault
    attr_reader :result

    # Initialize a new fault with the given result.
    #
    # @param result [Result] the result object that caused this fault
    #
    # @raise [ArgumentError] if result is nil or invalid
    #
    # @example
    #   fault = Fault.new(task_result)
    #   fault.result.reason # => "Task validation failed"
    def initialize(result)
      @result = result

      super(result.reason)
    end

    class << self

      # Create a fault class that matches specific task types.
      #
      # @param tasks [Array<Class>] array of task classes to match against
      #
      # @return [Class] a new fault class that matches the specified tasks
      #
      # @example
      #   Fault.for?(UserTask, AdminUserTask)
      #   # => true if fault.task is a UserTask or AdminUserTask
      def for?(*tasks)
        temp_fault = Class.new(self) do
          def self.===(other)
            other.is_a?(superclass) && @tasks.any? { |task| other.task.is_a?(task) }
          end
        end

        temp_fault.tap { |c| c.instance_variable_set(:@tasks, tasks) }
      end

      # Create a fault class that matches based on a custom block.
      #
      # @param block [Proc] block that determines if a fault matches
      #
      # @return [Class] a new fault class that matches based on the block
      #
      # @raise [ArgumentError] if no block is provided
      #
      # @example
      #   Fault.matches? { |fault| fault.result.metadata[:critical] }
      #   # => true if fault has critical metadata
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

  # Fault raised when a task is intentionally skipped during execution.
  #
  # This fault occurs when a task determines it should not execute based on
  # its current context or conditions. Skipped tasks are not considered failures
  # but rather intentional bypasses of task execution logic.
  SkipFault = Class.new(Fault)

  # Fault raised when a task execution fails due to errors or validation failures.
  #
  # This fault occurs when a task encounters an error condition, validation failure,
  # or any other condition that prevents successful completion. Failed tasks indicate
  # that the intended operation could not be completed successfully.
  FailFault = Class.new(Fault)

end

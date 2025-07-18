# frozen_string_literal: true

module CMDx
  # Represents the execution result of a task, tracking state, status, and metadata.
  #
  # Result objects encapsulate the outcome of task execution, providing detailed
  # information about execution state (initialized, executing, complete, interrupted),
  # status (success, skipped, failed), and associated metadata. They support
  # state transitions, status changes, and provide introspection capabilities
  # for debugging and monitoring task execution.
  class Result

    STATES = [
      INITIALIZED = "initialized",  # Initial state before execution
      EXECUTING   = "executing",    # Currently executing task logic
      COMPLETE    = "complete",     # Successfully completed execution
      INTERRUPTED = "interrupted"   # Execution was halted due to failure
    ].freeze
    STATUSES = [
      SUCCESS = "success",  # Task completed successfully
      SKIPPED = "skipped",  # Task was skipped intentionally
      FAILED  = "failed"    # Task failed due to error or validation
    ].freeze

    cmdx_attr_delegator :context, :chain,
                        to: :task

    # @return [CMDx::Task] The task instance that generated this result
    attr_reader :task

    # @return [String] The current execution state (initialized, executing, complete, interrupted)
    attr_reader :state

    # @return [String] The current execution status (success, skipped, failed)
    attr_reader :status

    # @return [Hash] Additional metadata associated with the result
    attr_reader :metadata

    # Initializes a new result for the given task
    #
    # @param task [CMDx::Task] the task to create a result for
    #
    # @return [CMDx::Result] a new result instance
    #
    # @raise [TypeError] if task is not a Task or Workflow
    #
    # @example Create a result for a task
    #   result = CMDx::Result.new(my_task)
    #   result.state   # => "initialized"
    #   result.status  # => "success"
    def initialize(task)
      raise TypeError, "must be a Task or Workflow" unless task.is_a?(Task)

      @task     = task
      @state    = INITIALIZED
      @status   = SUCCESS
      @metadata = {}
    end

    STATES.each do |s|
      # Checks if the result is in the specified state.
      #
      # @return [Boolean] true if the result matches the state
      #
      # @example Check if result is initialized
      #   result.initialized? # => true
      #
      # @example Check if result is executing
      #   result.executing? # => false
      #
      # @example Check if result is complete
      #   result.complete? # => false
      #
      # @example Check if result is interrupted
      #   result.interrupted? # => false
      define_method(:"#{s}?") { state == s }

      # Executes the provided block if the result is in the specified state.
      #
      # @param block [Proc] the block to execute if result matches the state
      #
      # @return [Result] returns self for method chaining
      #
      # @raise [ArgumentError] if no block is provided
      #
      # @example Handle initialized state
      #   result.on_initialized { |r| puts "Task is ready to start" }
      #
      # @example Handle executing state
      #   result.on_executing { |r| puts "Task is currently running" }
      #
      # @example Handle complete state
      #   result.on_complete { |r| puts "Task finished successfully" }
      #
      # @example Handle interrupted state
      #   result.on_interrupted { |r| puts "Task was interrupted" }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # Marks the result as executed by transitioning to complete or interrupted state
    # based on the current status
    #
    # @return [void]
    #
    # @example Mark successful task as executed
    #   result.executed!
    #   result.complete? # => true
    #
    # @example Mark failed task as executed
    #   result.fail!
    #   result.executed!
    #   result.interrupted? # => true
    def executed!
      success? ? complete! : interrupt!
    end

    # Checks if the result has been executed (either complete or interrupted)
    #
    # @return [Boolean] true if the result is complete or interrupted
    #
    # @example Check if result was executed
    #   result.executed? # => false
    #   result.executed!
    #   result.executed? # => true
    def executed?
      complete? || interrupted?
    end

    # Executes the provided block if the result has been executed
    #
    # @param block [Proc] the block to execute if result was executed
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle executed results
    #   result.on_executed { |r| puts "Task execution finished" }
    def on_executed(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if executed?
      self
    end

    # Transitions the result to executing state
    #
    # @return [void]
    #
    # @raise [RuntimeError] if not transitioning from initialized state
    #
    # @example Start task execution
    #   result.executing!
    #   result.executing? # => true
    def executing!
      return if executing?

      raise "can only transition to #{EXECUTING} from #{INITIALIZED}" unless initialized?

      @state = EXECUTING
    end

    # Transitions the result to complete state
    #
    # @return [void]
    #
    # @raise [RuntimeError] if not transitioning from executing state
    #
    # @example Complete task execution
    #   result.executing!
    #   result.complete!
    #   result.complete? # => true
    def complete!
      return if complete?

      raise "can only transition to #{COMPLETE} from #{EXECUTING}" unless executing?

      @state = COMPLETE
    end

    # Transitions the result to interrupted state
    #
    # @return [void]
    #
    # @raise [RuntimeError] if transitioning from complete state
    #
    # @example Interrupt task execution
    #   result.executing!
    #   result.interrupt!
    #   result.interrupted? # => true
    def interrupt!
      return if interrupted?

      raise "cannot transition to #{INTERRUPTED} from #{COMPLETE}" if complete?

      @state = INTERRUPTED
    end

    STATUSES.each do |s|
      # Checks if the result has the specified status.
      #
      # @return [Boolean] true if the result matches the status
      #
      # @example Check if result is successful
      #   result.success? # => true
      #
      # @example Check if result is skipped
      #   result.skipped? # => false
      #
      # @example Check if result is failed
      #   result.failed? # => false
      define_method(:"#{s}?") { status == s }

      # Executes the provided block if the result has the specified status.
      #
      # @param block [Proc] the block to execute if result matches the status
      #
      # @return [Result] returns self for method chaining
      #
      # @raise [ArgumentError] if no block is provided
      #
      # @example Handle successful status
      #   result.on_success { |r| puts "Task completed successfully" }
      #
      # @example Handle skipped status
      #   result.on_skipped { |r| puts "Task was skipped: #{r.metadata[:reason]}" }
      #
      # @example Handle failed status
      #   result.on_failed { |r| puts "Task failed: #{r.metadata[:error]}" }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # Checks if the result has a good outcome (not failed)
    #
    # @return [Boolean] true if the result is not failed
    #
    # @example Check for good outcome
    #   result.good? # => true (initially successful)
    #   result.fail!
    #   result.good? # => false
    def good?
      !failed?
    end

    # Executes the provided block if the result has a good outcome
    #
    # @param block [Proc] the block to execute if result is good
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle good results
    #   result.on_good { |r| puts "Task had good outcome" }
    def on_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    # Checks if the result has a bad outcome (not successful)
    #
    # @return [Boolean] true if the result is not successful
    #
    # @example Check for bad outcome
    #   result.bad? # => false (initially successful)
    #   result.skip!
    #   result.bad? # => true
    def bad?
      !success?
    end

    # Executes the provided block if the result has a bad outcome
    #
    # @param block [Proc] the block to execute if result is bad
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle bad outcome
    #   result.on_bad { |r| puts "Task had bad outcome: #{r.status}" }
    def on_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    # Transitions the result to skipped status and sets metadata
    #
    # @param metadata [Hash] additional metadata about why the task was skipped
    # @option metadata [String] :reason the reason for skipping
    # @option metadata [Exception] :original_exception the original exception that caused skipping
    #
    # @return [void]
    #
    # @raise [RuntimeError] if not transitioning from success status
    # @raise [CMDx::Fault] if no original_exception in metadata (via halt!)
    #
    # @example Skip a task with reason
    #   result.skip!(reason: "Dependencies not met")
    #   result.skipped? # => true
    #   result.metadata[:reason] # => "Dependencies not met"
    def skip!(**metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @status   = SKIPPED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Transitions the result to failed status and sets metadata
    #
    # @param metadata [Hash] additional metadata about the failure
    # @option metadata [String] :error the error message
    # @option metadata [Exception] :original_exception the original exception that caused failure
    #
    # @return [void]
    #
    # @raise [RuntimeError] if not transitioning from success status
    # @raise [CMDx::Fault] if no original_exception in metadata (via halt!)
    #
    # @example Fail a task with error message
    #   result.fail!(reason: "Database connection failed")
    #   result.failed? # => true
    #   result.metadata[:error] # => "Database connection failed"
    def fail!(**metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @status   = FAILED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Halts execution by raising a fault if the result is not successful
    #
    # @return [void]
    #
    # @raise [CMDx::Fault] if the result is not successful
    #
    # @example Halt on failed result
    #   result.fail!(reason: "Something went wrong")
    #   result.halt! # raises CMDx::Fault
    def halt!
      return if success?

      raise Fault.build(self)
    end

    # Throws the status and metadata from another result to this result
    #
    # @param result [CMDx::Result] the result to throw from
    # @param local_metadata [Hash] additional metadata to merge
    #
    # @return [void]
    #
    # @raise [TypeError] if result is not a Result instance
    #
    # @example Throw from a failed result
    #   failed_result = Result.new(task)
    #   failed_result.fail!(reason: "network timeout")
    #   current_result.throw!(failed_result)
    #   current_result.failed? # => true
    def throw!(result, local_metadata = {})
      raise TypeError, "must be a Result" unless result.is_a?(Result)

      md = result.metadata.merge(local_metadata)

      skip!(**md) if result.skipped?
      fail!(**md) if result.failed?
    end

    # Finds the result that originally caused a failure in the chain
    #
    # @return [CMDx::Result, nil] the result that caused the failure, or nil if not failed
    #
    # @example Find the original failure cause
    #   result.caused_failure # => #<Result task=OriginalTask status=failed>
    def caused_failure
      return unless failed?

      chain.results.reverse.find(&:failed?)
    end

    # Checks if this result caused a failure in the chain
    #
    # @return [Boolean] true if this result caused the failure
    #
    # @example Check if result caused failure
    #   result.caused_failure? # => true
    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    # Finds the result that this failure was thrown to
    #
    # @return [CMDx::Result, nil] the result that received the thrown failure, or nil if not failed
    #
    # @example Find where failure was thrown
    #   result.threw_failure # => #<Result task=PropagatorTask status=failed>
    def threw_failure
      return unless failed?

      results = chain.results.select(&:failed?)
      results.find { |r| r.index > index } || results.last
    end

    # Checks if this result threw a failure to another result
    #
    # @return [Boolean] true if this result threw a failure
    #
    # @example Check if result threw failure
    #   result.threw_failure? # => false
    def threw_failure?
      return false unless failed?

      threw_failure == self
    end

    # Checks if this result received a thrown failure from another result
    #
    # @return [Boolean] true if this result received a thrown failure
    #
    # @example Check if result received thrown failure
    #   result.thrown_failure? # => true
    def thrown_failure?
      failed? && !caused_failure?
    end

    # Returns the index of this result in the chain
    #
    # @return [Integer] the zero-based index of this result
    #
    # @example Get result index
    #   result.index # => 2
    def index
      chain.index(self)
    end

    # Returns the outcome of the result (state for certain cases, status otherwise)
    #
    # @return [String] the outcome (state or status)
    #
    # @example Get result outcome
    #   result.outcome # => "success"
    #   result.fail!
    #   result.outcome # => "failed"
    def outcome
      initialized? || thrown_failure? ? state : status
    end

    # Gets or measures the runtime of the result
    #
    # @param block [Proc] optional block to measure runtime for
    #
    # @return [Float, nil] the runtime in seconds, or nil if not measured
    #
    # @example Get existing runtime
    #   result.runtime # => 1.234
    #
    # @example Measure runtime with block
    #   result.runtime { sleep 1 } # => 1.0
    def runtime(&)
      return @runtime unless block_given?

      @runtime = Utils::MonotonicRuntime.call(&)
    end

    # Converts the result to a hash representation
    #
    # @return [Hash] serialized representation of the result
    #
    # @example Convert to hash
    #   result.to_h # => { state: "complete", status: "success", ... }
    def to_h
      ResultSerializer.call(self)
    end

    # Returns a string representation of the result
    #
    # @return [String] formatted string representation
    #
    # @example Convert to string
    #   result.to_s # => "Result[complete/success]"
    def to_s
      ResultInspector.call(to_h)
    end

    # Deconstructs the result for pattern matching
    #
    # @return [Array<String>] array containing state and status
    #
    # @example Pattern matching with deconstruct
    #   case result
    #   in ["complete", "success"]
    #     puts "Task completed successfully"
    #   end
    def deconstruct
      [state, status]
    end

    # Deconstructs the result with keys for pattern matching
    #
    # @param keys [Array<Symbol>, nil] specific keys to include in deconstruction
    #
    # @return [Hash] hash with requested attributes
    #
    # @example Pattern matching with specific keys
    #   case result
    #   in { state: "complete", good: true }
    #     puts "Task finished well"
    #   end
    def deconstruct_keys(keys)
      attributes = {
        state: state,
        status: status,
        metadata: metadata,
        executed: executed?,
        good: good?,
        bad: bad?
      }

      return attributes if keys.nil?

      attributes.slice(*keys)
    end

  end
end

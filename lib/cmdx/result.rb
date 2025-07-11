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

    # Creates a new Result instance for the specified task.
    #
    # @param task [CMDx::Task] the task instance that will generate this result
    #
    # @return [Result] a new Result instance
    #
    # @raise [TypeError] if task is not a Task or Workflow instance
    #
    # @example Create a result for a task
    #   task = MyTask.new
    #   result = Result.new(task)
    #   result.state # => "initialized"
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

    # Transitions the result to its final executed state based on current status.
    #
    # @return [Result] returns self for method chaining
    #
    # @example Complete successful execution
    #   result.success? # => true
    #   result.executed! # transitions to complete
    #   result.complete? # => true
    #
    # @example Handle failed execution
    #   result.fail!
    #   result.executed! # transitions to interrupted
    #   result.interrupted? # => true
    def executed!
      success? ? complete! : interrupt!
    end

    # Checks if the result has finished executing (either complete or interrupted).
    #
    # @return [Boolean] true if the result is in a final execution state
    #
    # @example Check execution completion
    #   result.executed? # => false
    #   result.complete!
    #   result.executed? # => true
    def executed?
      complete? || interrupted?
    end

    # Executes the provided block if the result has finished executing.
    #
    # @param block [Proc] the block to execute if result is executed
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle executed result
    #   result.on_executed { |r| puts "Task completed with #{r.status}" }
    def on_executed(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if executed?
      self
    end

    # Transitions the result to executing state.
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [RuntimeError] if not transitioning from initialized state
    #
    # @example Start task execution
    #   result.initialized? # => true
    #   result.executing!
    #   result.executing? # => true
    def executing!
      return if executing?

      raise "can only transition to #{EXECUTING} from #{INITIALIZED}" unless initialized?

      @state = EXECUTING
    end

    # Transitions the result to complete state.
    #
    # @return [Result] returns self for method chaining
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

    # Transitions the result to interrupted state due to failure.
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [RuntimeError] if trying to transition from complete state
    #
    # @example Interrupt execution on failure
    #   result.executing!
    #   result.fail!
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

    # Checks if the result has a positive outcome (not failed).
    #
    # @return [Boolean] true if the result is successful or skipped
    #
    # @example Check for good outcome
    #   result.good? # => true (success or skipped)
    #   result.fail!
    #   result.good? # => false
    def good?
      !failed?
    end

    # Executes the provided block if the result has a good outcome.
    #
    # @param block [Proc] the block to execute if result is good
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle good outcome
    #   result.on_good { |r| puts "Task succeeded with #{r.status}" }
    def on_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    # Checks if the result has a negative outcome (not successful).
    #
    # @return [Boolean] true if the result is skipped or failed
    #
    # @example Check for bad outcome
    #   result.bad? # => false (initially successful)
    #   result.skip!
    #   result.bad? # => true
    def bad?
      !success?
    end

    # Executes the provided block if the result has a bad outcome.
    #
    # @param block [Proc] the block to execute if result is bad
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [ArgumentError] if no block is provided
    #
    # @example Handle bad outcome
    #   result.on_bad { |r| puts "Task had issues: #{r.status}" }
    def on_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    # Transitions the result to skipped status with optional metadata.
    #
    # @param metadata [Hash] additional metadata to store with the skip
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [RuntimeError] if not transitioning from success status
    #
    # @example Skip a task with reason
    #   result.skip!(reason: "condition not met")
    #   result.skipped? # => true
    #   result.metadata[:reason] # => "condition not met"
    def skip!(**metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @status   = SKIPPED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Transitions the result to failed status with optional metadata.
    #
    # @param metadata [Hash] additional metadata to store with the failure
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [RuntimeError] if not transitioning from success status
    #
    # @example Fail a task with error details
    #   result.fail!(error: "validation failed", code: 422)
    #   result.failed? # => true
    #   result.metadata[:error] # => "validation failed"
    def fail!(**metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @status   = FAILED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Raises a Fault exception to halt execution chain if result is not successful.
    #
    # @return [nil] never returns normally
    #
    # @raise [Fault] if the result is not successful
    #
    # @example Halt execution on failure
    #   result.fail!
    #   result.halt! # raises Fault
    def halt!
      return if success?

      raise Fault.build(self)
    end

    # Propagates status and metadata from another result to this result.
    #
    # @param result [Result] the result to throw/propagate from
    # @param local_metadata [Hash] additional metadata to merge
    #
    # @return [Result] returns self for method chaining
    #
    # @raise [TypeError] if result is not a Result instance
    #
    # @example Throw failure from another result
    #   failed_result = Result.new(task)
    #   failed_result.fail!(error: "network timeout")
    #   current_result.throw!(failed_result)
    #   current_result.failed? # => true
    def throw!(result, local_metadata = {})
      raise TypeError, "must be a Result" unless result.is_a?(Result)

      md = result.metadata.merge(local_metadata)

      skip!(**md) if result.skipped?
      fail!(**md) if result.failed?
    end

    # Finds the original result that caused a failure in the execution chain.
    #
    # @return [Result, nil] the result that originally caused the failure, or nil if not failed
    #
    # @example Find original failure cause
    #   chain.results.last.caused_failure
    #   # => #<Result task=OriginalTask status=failed>
    def caused_failure
      return unless failed?

      chain.results.reverse.find(&:failed?)
    end

    # Checks if this result is the original cause of failure in the chain.
    #
    # @return [Boolean] true if this result caused the failure chain
    #
    # @example Check if this result caused failure
    #   result.caused_failure? # => true if this is the original failure
    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    # Finds the result that threw/propagated this failure.
    #
    # @return [Result, nil] the result that threw this failure, or nil if not applicable
    #
    # @example Find failure propagator
    #   result.threw_failure
    #   # => #<Result task=PropagatorTask status=failed>
    def threw_failure
      return unless failed?

      results = chain.results.select(&:failed?)
      results.find { |r| r.index > index } || results.last
    end

    # Checks if this result threw/propagated a failure.
    #
    # @return [Boolean] true if this result threw a failure
    #
    # @example Check if this result threw failure
    #   result.threw_failure? # => true if this result propagated failure
    def threw_failure?
      return false unless failed?

      threw_failure == self
    end

    # Checks if this result represents a propagated failure (not the original cause).
    #
    # @return [Boolean] true if this is a propagated failure
    #
    # @example Check if failure was propagated
    #   result.thrown_failure? # => true if failure came from earlier in chain
    def thrown_failure?
      failed? && !caused_failure?
    end

    # Gets the index position of this result in the execution chain.
    #
    # @return [Integer] the zero-based index position in the chain
    #
    # @example Get result position
    #   result.index # => 2 (third result in chain)
    def index
      chain.index(self)
    end

    # Determines the overall outcome of this result.
    #
    # @return [String] the outcome - state for certain conditions, status otherwise
    #
    # @example Get result outcome
    #   result.outcome # => "success" or "failed" or "initialized"
    def outcome
      initialized? || thrown_failure? ? state : status
    end

    # Gets or measures the runtime duration of the result's execution.
    #
    # @param block [Proc] optional block to measure execution time
    #
    # @return [Float, nil] the runtime in seconds, or nil if not measured
    #
    # @example Get existing runtime
    #   result.runtime # => 0.523 (seconds)
    #
    # @example Measure execution time
    #   result.runtime { sleep 1; do_work }
    #   result.runtime # => 1.001
    def runtime(&)
      return @runtime unless block_given?

      @runtime = Utils::MonotonicRuntime.call(&)
    end

    # Converts the result to a hash representation.
    #
    # @return [Hash] hash representation of the result
    #
    # @example Convert to hash
    #   result.to_h
    #   # => {state: "complete", status: "success", metadata: {}}
    def to_h
      ResultSerializer.call(self)
    end

    # Returns a string representation of the result.
    #
    # @return [String] formatted string representation
    #
    # @example Get string representation
    #   result.to_s
    #   # => "MyTask [complete/success]"
    def to_s
      ResultInspector.call(to_h)
    end

    # Deconstructs the result for pattern matching.
    #
    # @return [Array] array containing state and status
    #
    # @example Pattern match on result
    #   case result
    #   in ["complete", "success"]
    #     puts "Task completed successfully"
    #   end
    def deconstruct
      [state, status]
    end

    # Deconstructs the result to a hash for pattern matching with keys.
    #
    # @param keys [Array<Symbol>, nil] specific keys to extract, or nil for all
    #
    # @return [Hash] hash containing requested attributes
    #
    # @example Pattern match with keys
    #   case result
    #   in {state: "complete", good: true}
    #     puts "Task completed successfully"
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

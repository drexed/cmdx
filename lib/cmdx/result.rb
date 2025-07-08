# frozen_string_literal: true

module CMDx
  # Result object representing the outcome of task execution.
  #
  # The Result class encapsulates all information about a task's execution,
  # including its state, status, metadata, and runtime information. It provides
  # a comprehensive interface for tracking task lifecycle, handling failures,
  # and chaining execution outcomes.
  #
  # @example Basic result usage
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.success?   # => true
  #   result.complete?  # => true
  #   result.runtime    # => 0.5
  #
  # @example Result with failure handling
  #   result = ProcessOrderTask.call(invalid_params)
  #   result.failed?    # => true
  #   result.bad?       # => true
  #   result.metadata   # => { reason: "Invalid parameters" }
  #
  # @example Result state callbacks
  #   ProcessOrderTask.call(order_id: 123)
  #     .on_success { |result| logger.info "Order processed successfully" }
  #     .on_failed { |result| logger.error "Order processing failed: #{result.metadata[:reason]}" }
  #
  # @example Result chaining and failure propagation
  #   result1 = FirstTask.call
  #   result2 = SecondTask.call
  #   result2.throw!(result1) if result1.failed?  # Propagate failure
  #
  # @see CMDx::Task Task execution and result creation
  # @see CMDx::Chain Chain execution context and result tracking
  # @see CMDx::Fault Fault handling for result failures
  class Result

    __cmdx_attr_delegator :context, :chain,
                          to: :task

    # @return [CMDx::Task] The task instance that generated this result
    attr_reader :task

    # @return [String] The current execution state (initialized, executing, complete, interrupted)
    attr_reader :state

    # @return [String] The current execution status (success, skipped, failed)
    attr_reader :status

    # @return [Hash] Additional metadata associated with the result
    attr_reader :metadata

    # Initializes a new Result instance.
    #
    # Creates a result object for tracking task execution outcomes.
    # Results start in initialized state with success status.
    #
    # @param task [CMDx::Task] The task instance this result belongs to
    # @raise [TypeError] If task is not a Task or Workflow instance
    #
    # @example Creating a result
    #   task = ProcessOrderTask.new
    #   result = Result.new(task)
    #   result.initialized?  # => true
    #   result.success?      # => true
    def initialize(task)
      raise TypeError, "must be a Task or Workflow" unless task.is_a?(Task)

      @task     = task
      @state    = INITIALIZED
      @status   = SUCCESS
      @metadata = {}
    end

    # Available execution states for task results.
    #
    # States represent the execution lifecycle of a task from initialization
    # through completion or interruption.
    STATES = [
      INITIALIZED = "initialized",  # Initial state before execution
      EXECUTING   = "executing",    # Currently executing task logic
      COMPLETE    = "complete",     # Successfully completed execution
      INTERRUPTED = "interrupted"   # Execution was halted due to failure
    ].freeze

    # Dynamically defines state predicate and callback methods.
    #
    # For each state, creates:
    # - Predicate method (e.g., `executing?`)
    # - Callback method (e.g., `on_executing`)
    STATES.each do |s|
      # eg: executing?
      define_method(:"#{s}?") { state == s }

      # eg: on_interrupted { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # Marks the result as executed based on current status.
    #
    # Transitions to complete state if successful, or interrupted state
    # if the task has failed or been skipped.
    #
    # @return [void]
    #
    # @example Successful execution
    #   result.executed!
    #   result.complete?  # => true (if status was success)
    #
    # @example Failed execution
    #   result.fail!(reason: "Something went wrong")
    #   result.executed!
    #   result.interrupted?  # => true
    def executed!
      success? ? complete! : interrupt!
    end

    # Checks if the result has been executed (completed or interrupted).
    #
    # @return [Boolean] true if result is complete or interrupted
    #
    # @example
    #   result.executed?  # => true if complete? || interrupted?
    def executed?
      complete? || interrupted?
    end

    # Executes a callback if the result has been executed.
    #
    # @yield [Result] The result instance
    # @return [Result] Self for method chaining
    # @raise [ArgumentError] If no block is provided
    #
    # @example
    #   result.on_executed { |r| logger.info "Task finished: #{r.status}" }
    def on_executed(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if executed?
      self
    end

    # Transitions the result to executing state.
    #
    # @return [void]
    # @raise [RuntimeError] If not transitioning from initialized state
    #
    # @example
    #   result.executing!
    #   result.executing?  # => true
    def executing!
      return if executing?

      raise "can only transition to #{EXECUTING} from #{INITIALIZED}" unless initialized?

      @state = EXECUTING
    end

    # Transitions the result to complete state.
    #
    # @return [void]
    # @raise [RuntimeError] If not transitioning from executing state
    #
    # @example
    #   result.complete!
    #   result.complete?  # => true
    def complete!
      return if complete?

      raise "can only transition to #{COMPLETE} from #{EXECUTING}" unless executing?

      @state = COMPLETE
    end

    # Transitions the result to interrupted state.
    #
    # @return [void]
    # @raise [RuntimeError] If trying to interrupt from complete state
    #
    # @example
    #   result.interrupt!
    #   result.interrupted?  # => true
    def interrupt!
      return if interrupted?

      raise "cannot transition to #{INTERRUPTED} from #{COMPLETE}" if complete?

      @state = INTERRUPTED
    end

    # Available execution statuses for task results.
    #
    # Statuses represent the outcome of task logic execution.
    STATUSES = [
      SUCCESS = "success",  # Task completed successfully
      SKIPPED = "skipped",  # Task was skipped intentionally
      FAILED  = "failed"    # Task failed due to error or validation
    ].freeze

    # Dynamically defines status predicate and callback methods.
    #
    # For each status, creates:
    # - Predicate method (e.g., `success?`)
    # - Callback method (e.g., `on_success`)
    STATUSES.each do |s|
      # eg: skipped?
      define_method(:"#{s}?") { status == s }

      # eg: on_failed { ... }
      define_method(:"on_#{s}") do |&block|
        raise ArgumentError, "block required" unless block

        block.call(self) if send(:"#{s}?")
        self
      end
    end

    # Checks if the result represents a good outcome (success or skipped).
    #
    # @return [Boolean] true if not failed
    #
    # @example
    #   result.good?  # => true if success? || skipped?
    def good?
      !failed?
    end

    # Executes a callback if the result has a good outcome.
    #
    # @yield [Result] The result instance
    # @return [Result] Self for method chaining
    # @raise [ArgumentError] If no block is provided
    #
    # @example
    #   result.on_good { |r| logger.info "Task completed successfully" }
    def on_good(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if good?
      self
    end

    # Checks if the result represents a bad outcome (skipped or failed).
    #
    # @return [Boolean] true if not successful
    #
    # @example
    #   result.bad?  # => true if skipped? || failed?
    def bad?
      !success?
    end

    # Executes a callback if the result has a bad outcome.
    #
    # @yield [Result] The result instance
    # @return [Result] Self for method chaining
    # @raise [ArgumentError] If no block is provided
    #
    # @example
    #   result.on_bad { |r| logger.error "Task had issues: #{r.status}" }
    def on_bad(&)
      raise ArgumentError, "block required" unless block_given?

      yield(self) if bad?
      self
    end

    # Marks the result as skipped with optional metadata.
    #
    # Transitions from success to skipped status and halts execution
    # unless the skip was caused by an original exception.
    #
    # @param metadata [Hash] Additional metadata about the skip
    # @return [void]
    # @raise [RuntimeError] If not transitioning from success status
    # @raise [CMDx::Fault] If halting due to skip (unless original_exception present)
    #
    # @example Basic skip
    #   result.skip!(reason: "Order already processed")
    #   result.skipped?  # => true
    #
    # @example Skip with exception context
    #   result.skip!(original_exception: StandardError.new("DB unavailable"))
    def skip!(**metadata)
      return if skipped?

      raise "can only transition to #{SKIPPED} from #{SUCCESS}" unless success?

      @status   = SKIPPED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Marks the result as failed with optional metadata.
    #
    # Transitions from success to failed status and halts execution
    # unless the failure was caused by an original exception.
    #
    # @param metadata [Hash] Additional metadata about the failure
    # @return [void]
    # @raise [RuntimeError] If not transitioning from success status
    # @raise [CMDx::Fault] If halting due to failure (unless original_exception present)
    #
    # @example Basic failure
    #   result.fail!(reason: "Invalid order data", code: 422)
    #   result.failed?  # => true
    #
    # @example Failure with exception context
    #   result.fail!(original_exception: StandardError.new("Validation failed"))
    def fail!(**metadata)
      return if failed?

      raise "can only transition to #{FAILED} from #{SUCCESS}" unless success?

      @status   = FAILED
      @metadata = metadata

      halt! unless metadata[:original_exception]
    end

    # Halts execution by raising a fault if the result is not successful.
    #
    # @return [void]
    # @raise [CMDx::Fault] If result status is not success
    #
    # @example
    #   result.fail!(reason: "Something went wrong")
    #   result.halt!  # Raises CMDx::Fault
    def halt!
      return if success?

      raise Fault.build(self)
    end

    # Propagates another result's failure status to this result.
    #
    # Copies the failure or skip status from another result, merging
    # metadata and preserving failure chain information.
    #
    # @param result [CMDx::Result] The result to propagate from
    # @param local_metadata [Hash] Additional metadata to merge
    # @return [void]
    # @raise [TypeError] If result parameter is not a Result instance
    #
    # @example Propagating failure
    #   first_result = FirstTask.call
    #   second_result = SecondTask.call
    #   second_result.throw!(first_result) if first_result.failed?
    #
    # @example Propagating with additional context
    #   result.throw!(other_result, context: "During order processing")
    def throw!(result, local_metadata = {})
      raise TypeError, "must be a Result" unless result.is_a?(Result)

      md = result.metadata.merge(local_metadata)

      skip!(**md) if result.skipped?
      fail!(**md) if result.failed?
    end

    # Finds the result that originally caused a failure in the execution chain.
    #
    # @return [CMDx::Result, nil] The result that first failed, or nil if not failed
    #
    # @example
    #   failed_result = result.caused_failure
    #   puts "Original failure: #{failed_result.metadata[:reason]}" if failed_result
    def caused_failure
      return unless failed?

      chain.results.reverse.find(&:failed?)
    end

    # Checks if this result was the original cause of failure.
    #
    # @return [Boolean] true if this result caused the failure chain
    #
    # @example
    #   result.caused_failure?  # => true if this result started the failure chain
    def caused_failure?
      return false unless failed?

      caused_failure == self
    end

    # Finds the result that threw/propagated the failure to this result.
    #
    # @return [CMDx::Result, nil] The result that threw the failure, or nil if not failed
    #
    # @example
    #   throwing_result = result.threw_failure
    #   puts "Failure thrown by: #{throwing_result.task.class}" if throwing_result
    def threw_failure
      return unless failed?

      results = chain.results.select(&:failed?)
      results.find { |r| r.index > index } || results.last
    end

    # Checks if this result threw/propagated a failure.
    #
    # @return [Boolean] true if this result threw a failure to another result
    #
    # @example
    #   result.threw_failure?  # => true if this result propagated failure
    def threw_failure?
      return false unless failed?

      threw_failure == self
    end

    # Checks if this result received a thrown failure (not the original cause).
    #
    # @return [Boolean] true if failed but not the original cause
    #
    # @example
    #   result.thrown_failure?  # => true if failed due to propagated failure
    def thrown_failure?
      failed? && !caused_failure?
    end

    # Gets the index of this result within the execution chain.
    #
    # @return [Integer] The zero-based index of this result in the chain
    #
    # @example
    #   result.index  # => 0 for first result, 1 for second, etc.
    def index
      chain.index(self)
    end

    # Gets the outcome of the result based on state and status.
    #
    # Returns state for initialized results or thrown failures,
    # otherwise returns the status.
    #
    # @return [String] The result outcome (state or status)
    #
    # @example
    #   result.outcome  # => "success", "failed", "interrupted", etc.
    def outcome
      initialized? || thrown_failure? ? state : status
    end

    # Measures and returns the runtime of a block execution.
    #
    # If called without a block, returns the stored runtime value.
    # If called with a block, executes and measures the execution
    # time using monotonic clock.
    #
    # @yield Block to execute and measure
    # @return [Float] Runtime in seconds
    #
    # @example Getting stored runtime
    #   result.runtime  # => 0.5
    #
    # @example Measuring block execution
    #   result.runtime do
    #     # Task execution logic
    #     perform_work
    #   end  # => 0.5 (and stores the runtime)
    def runtime(&)
      return @runtime unless block_given?

      @runtime = Utils::MonotonicRuntime.call(&)
    end

    # Converts the result to a hash representation.
    #
    # @return [Hash] Serialized result data including task info, state, status, and metadata
    #
    # @example
    #   result.to_h
    #   # => {
    #   #   class: "ProcessOrderTask",
    #   #   type: "Task",
    #   #   index: 0,
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   metadata: {},
    #   #   runtime: 0.5
    #   # }
    def to_h
      ResultSerializer.call(self)
    end

    # Converts the result to a string representation for inspection.
    #
    # @return [String] Human-readable result description
    #
    # @example
    #   result.to_s
    #   # => "ProcessOrderTask: type=Task index=0 id=018c2b95... state=complete status=success outcome=success runtime=0.5"
    def to_s
      ResultInspector.call(to_h)
    end

    # Deconstructs the result for array pattern matching.
    #
    # Enables pattern matching with array syntax to match against
    # state and status in order.
    #
    # @return [Array<String>] Array containing [state, status]
    #
    # @example Array pattern matching
    #   result = ProcessOrderTask.call(order_id: 123)
    #   case result
    #   in ["complete", "success"]
    #     puts "Task completed successfully"
    #   in ["interrupted", "failed"]
    #     puts "Task failed"
    #   end
    def deconstruct
      [state, status]
    end

    # Deconstructs the result for hash pattern matching.
    #
    # Enables pattern matching with hash syntax to match against
    # specific result attributes.
    #
    # @param keys [Array<Symbol>] Specific keys to extract (optional)
    # @return [Hash] Hash containing result attributes
    #
    # @example Hash pattern matching
    #   result = ProcessOrderTask.call(order_id: 123)
    #   case result
    #   in { state: "complete", status: "success" }
    #     puts "Success!"
    #   in { state: "interrupted", status: "failed", metadata: { reason: String => reason } }
    #     puts "Failed: #{reason}"
    #   end
    #
    # @example Specific key extraction
    #   result.deconstruct_keys([:state, :status])
    #   # => { state: "complete", status: "success" }
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

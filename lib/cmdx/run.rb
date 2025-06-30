# frozen_string_literal: true

module CMDx
  # Run execution context for tracking related task executions with correlation support.
  #
  # The Run class represents a collection of related task executions that share
  # a common execution context. It provides unified tracking, indexing, and
  # reporting for groups of tasks executed together, enabling comprehensive
  # monitoring of complex business logic workflows.
  #
  # ## Correlation ID Integration
  #
  # Run instances automatically inherit correlation IDs from the current thread's
  # correlation context via CMDx::Correlator. This enables seamless request
  # tracking across task boundaries without explicit parameter passing.
  #
  # The run ID follows this precedence:
  # 1. Explicitly provided `:id` attribute
  # 2. Current thread's correlation ID (via CMDx::Correlator.id)
  # 3. Generated UUID (via CMDx::Correlator.generate)
  #
  # @example Basic run usage with automatic correlation
  #   CMDx::Correlator.id = "req-12345"
  #   result = ProcessOrderTask.call(order_id: 123)
  #   run = result.run
  #   run.id        # => "req-12345" (inherited from correlator)
  #   run.results   # => [#<CMDx::Result...>]
  #   run.state     # => "complete"
  #   run.status    # => "success"
  #
  # @example Run with multiple related tasks sharing correlation
  #   CMDx::Correlator.use("batch-operation-456") do
  #     class ProcessOrderTask < CMDx::Task
  #       def call
  #         # Subtasks inherit the same correlation ID for tracking
  #         SendEmailConfirmationTask.call(context)
  #         NotifyPartnerWarehousesTask.call(context)
  #       end
  #     end
  #
  #     result = ProcessOrderTask.call(order_id: 123)
  #     run = result.run
  #     run.id  # => "batch-operation-456" (same across all tasks)
  #     run.results.size  # => 3 (ProcessOrderTask + 2 subtasks)
  #     run.results.map(&:task).map(&:class)
  #     # => [ProcessOrderTask, SendEmailConfirmationTask, NotifyPartnerWarehousesTask]
  #   end
  #
  # @example Explicit run ID overrides correlation
  #   CMDx::Correlator.id = "req-12345"
  #   context = { order_id: 123, run: { id: "custom-run-789" } }
  #   result = ProcessOrderTask.call(context)
  #   result.run.id  # => "custom-run-789" (explicit ID takes precedence)
  #
  # @example Run state and outcome tracking
  #   result = ComplexTask.call
  #   run = result.run
  #
  #   run.state     # => Delegates to first result's state
  #   run.status    # => Delegates to first result's status
  #   run.outcome   # => Delegates to first result's outcome
  #   run.runtime   # => Delegates to first result's runtime
  #
  # @example Run inspection and debugging
  #   run.to_h      # => Hash representation of run and all results
  #   run.to_s      # => Human-readable run summary with all tasks
  #
  # @see CMDx::Result Individual task execution results
  # @see CMDx::Task Task execution and run context
  # @see CMDx::Context Context sharing between related tasks
  # @see CMDx::Correlator Thread-safe correlation ID management
  class Run

    __cmdx_attr_delegator :index, to: :results
    __cmdx_attr_delegator :state, :status, :outcome, :runtime, to: :first_result

    # @return [String] Correlation identifier for tracking across request boundaries (inherits from CMDx::Correlator)
    # @return [Array<CMDx::Result>] Collection of results from related task executions
    attr_reader :id, :results

    # Initializes a new Run instance with automatic correlation ID inheritance.
    #
    # Creates a run context for tracking related task executions with an
    # identifier that follows the correlation precedence hierarchy:
    # 1. Explicitly provided `:id` attribute
    # 2. Current thread's correlation ID (via CMDx::Correlator.id)
    # 3. Generated UUID (via CMDx::Correlator.generate)
    #
    # This automatic correlation inheritance enables seamless request tracking
    # across task boundaries without requiring manual correlation ID management.
    #
    # @param attributes [Hash] Run initialization attributes
    # @option attributes [String] :id (correlation ID or generated UUID) Run identifier
    # @option attributes [Array<CMDx::Result>] :results ([]) Initial results collection
    #
    # @example Creating a run with automatic correlation inheritance
    #   CMDx::Correlator.id = "req-12345"
    #   run = Run.new
    #   run.id  # => "req-12345" (inherited from current correlation)
    #
    # @example Creating a run with explicit ID (overrides correlation)
    #   CMDx::Correlator.id = "req-12345"
    #   run = Run.new(id: "custom-run-789")
    #   run.id  # => "custom-run-789" (explicit ID takes precedence)
    #
    # @example Creating a run without correlation context
    #   CMDx::Correlator.clear  # No correlation ID set
    #   run = Run.new
    #   run.id  # => "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated UUID)
    #
    # @example Creating a run with initial results
    #   existing_results = [result1, result2]
    #   run = Run.new(results: existing_results)
    #   run.results.size  # => 2
    #
    # @example Block-based correlation context
    #   CMDx::Correlator.use("batch-operation") do
    #     run = Run.new
    #     run.id  # => "batch-operation" (from correlation context)
    #   end
    def initialize(attributes = {})
      @id      = attributes[:id] || CMDx::Correlator.id || CMDx::Correlator.generate
      @results = Array(attributes[:results])
    end

    # Freezes the run and ensures first result is memoized.
    #
    # Ensures the first result is cached before freezing to prevent
    # issues with delegation after the object becomes immutable.
    #
    # @return [Run] The frozen run instance
    #
    # @example
    #   run.freeze
    #   run.frozen?  # => true
    def freeze
      first_result
      super
    end

    # Gets the index of a specific result within this run.
    #
    # Delegates to the results array to find the index of a given result,
    # enabling position tracking within the execution sequence.
    #
    # @param result [CMDx::Result] The result to find the index for
    # @return [Integer, nil] The zero-based index or nil if not found
    #
    # @example
    #   run.index(result)  # => 0 for first result, 1 for second, etc.
    #
    # @note This method is delegated from the results array via __cmdx_attr_delegator
    def index(result)
      results.index(result)
    end

    # Gets the execution state of the run.
    #
    # Delegates to the first result's state, representing the overall
    # execution state of the run based on the primary task.
    #
    # @return [String] The execution state (initialized, executing, complete, interrupted)
    #
    # @example
    #   run.state  # => "complete"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def state
      first_result&.state
    end

    # Gets the execution status of the run.
    #
    # Delegates to the first result's status, representing the overall
    # execution outcome of the run based on the primary task.
    #
    # @return [String] The execution status (success, skipped, failed)
    #
    # @example
    #   run.status  # => "success"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def status
      first_result&.status
    end

    # Gets the execution outcome of the run.
    #
    # Delegates to the first result's outcome, representing the final
    # outcome of the run based on the primary task.
    #
    # @return [String] The execution outcome
    #
    # @example
    #   run.outcome  # => "success"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def outcome
      first_result&.outcome
    end

    # Gets the total runtime of the run.
    #
    # Delegates to the first result's runtime, representing the execution
    # time of the primary task in the run.
    #
    # @return [Float] Runtime in seconds
    #
    # @example
    #   run.runtime  # => 0.5
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def runtime
      first_result&.runtime
    end

    # Converts the run to a hash representation.
    #
    # Serializes the run and all its results into a structured hash
    # suitable for logging, debugging, and data interchange.
    #
    # @return [Hash] Structured hash representation of the run
    #
    # @example
    #   run.to_h
    #   # => {
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   runtime: 0.5,
    #   #   results: [
    #   #     { class: "ProcessOrderTask", state: "complete", status: "success", ... },
    #   #     { class: "SendEmailTask", state: "complete", status: "success", ... }
    #   #   ]
    #   # }
    def to_h
      RunSerializer.call(self)
    end
    alias to_a to_h

    # Converts the run to a string representation for inspection.
    #
    # Creates a comprehensive, human-readable summary of the run including
    # all task results with formatted headers and footers.
    #
    # @return [String] Formatted run summary with task details
    #
    # @example
    #   run.to_s
    #   # => "
    #   #   run: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   ProcessOrderTask: index=0 state=complete status=success ...
    #   #   SendEmailTask: index=1 state=complete status=success ...
    #   #
    #   #   ================================================
    #   #   state: complete | status: success | outcome: success | runtime: 0.5
    #   #   "
    def to_s
      RunInspector.call(self)
    end

    private

    # Gets the first result in the run with memoization.
    #
    # Caches the first result to avoid repeated array access and ensure
    # consistent delegation behavior.
    #
    # @return [CMDx::Result, nil] The first result or nil if no results
    def first_result
      return @first_result if defined?(@first_result)

      @first_result = @results.first
    end

  end
end

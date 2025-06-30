# frozen_string_literal: true

module CMDx
  # Chain execution context for tracking related task executions with correlation support.
  #
  # The Chain class represents a collection of related task executions that share
  # a common execution context. It provides unified tracking, indexing, and
  # reporting for groups of tasks executed together, enabling comprehensive
  # monitoring of complex business logic workflows.
  #
  # ## Correlation ID Integration
  #
  # Chain instances automatically inherit correlation IDs from the current thread's
  # correlation context via CMDx::Correlator. This enables seamless request
  # tracking across task boundaries without explicit parameter passing.
  #
  # The chain ID follows this precedence:
  # 1. Explicitly provided `:id` attribute
  # 2. Current thread's correlation ID (via CMDx::Correlator.id)
  # 3. Generated UUID (via CMDx::Correlator.generate)
  #
  # @example Basic chain usage with automatic correlation
  #   CMDx::Correlator.id = "req-12345"
  #   result = ProcessOrderTask.call(order_id: 123)
  #   chain = result.chain
  #   chain.id        # => "req-12345" (inherited from correlator)
  #   chain.results   # => [#<CMDx::Result...>]
  #   chain.state     # => "complete"
  #   chain.status    # => "success"
  #
  # @example Chain with multiple related tasks sharing correlation
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
  #     chain = result.chain
  #     chain.id  # => "batch-operation-456" (same across all tasks)
  #     chain.results.size  # => 3 (ProcessOrderTask + 2 subtasks)
  #     chain.results.map(&:task).map(&:class)
  #     # => [ProcessOrderTask, SendEmailConfirmationTask, NotifyPartnerWarehousesTask]
  #   end
  #
  # @example Explicit chain ID overrides correlation
  #   CMDx::Correlator.id = "req-12345"
  #   context = { order_id: 123, chain: { id: "custom-chain-789" } }
  #   result = ProcessOrderTask.call(context)
  #   result.chain.id  # => "custom-chain-789" (explicit ID takes precedence)
  #
  # @example Chain state and outcome tracking
  #   result = ComplexTask.call
  #   chain = result.chain
  #
  #   chain.state     # => Delegates to first result's state
  #   chain.status    # => Delegates to first result's status
  #   chain.outcome   # => Delegates to first result's outcome
  #   chain.runtime   # => Delegates to first result's runtime
  #
  # @example Chain inspection and debugging
  #   chain.to_h      # => Hash representation of chain and all results
  #   chain.to_s      # => Human-readable chain summary with all tasks
  #
  # @see CMDx::Result Individual task execution results
  # @see CMDx::Task Task execution and chain context
  # @see CMDx::Context Context sharing between related tasks
  # @see CMDx::Correlator Thread-safe correlation ID management
  class Chain

    __cmdx_attr_delegator :index, to: :results
    __cmdx_attr_delegator :state, :status, :outcome, :runtime, to: :first_result

    # @return [String] Correlation identifier for tracking across request boundaries (inherits from CMDx::Correlator)
    # @return [Array<CMDx::Result>] Collection of results from related task executions
    attr_reader :id, :results

    # Initializes a new Chain instance with automatic correlation ID inheritance.
    #
    # Creates a chain context for tracking related task executions with an
    # identifier that follows the correlation precedence hierarchy:
    # 1. Explicitly provided `:id` attribute
    # 2. Current thread's correlation ID (via CMDx::Correlator.id)
    # 3. Generated UUID (via CMDx::Correlator.generate)
    #
    # This automatic correlation inheritance enables seamless request tracking
    # across task boundaries without requiring manual correlation ID management.
    #
    # @param attributes [Hash] Chain initialization attributes
    # @option attributes [String] :id (correlation ID or generated UUID) Chain identifier
    # @option attributes [Array<CMDx::Result>] :results ([]) Initial results collection
    #
    # @example Creating a chain with automatic correlation inheritance
    #   CMDx::Correlator.id = "req-12345"
    #   chain = Chain.new
    #   chain.id  # => "req-12345" (inherited from current correlation)
    #
    # @example Creating a chain with explicit ID (overrides correlation)
    #   CMDx::Correlator.id = "req-12345"
    #   chain = Chain.new(id: "custom-chain-789")
    #   chain.id  # => "custom-chain-789" (explicit ID takes precedence)
    #
    # @example Creating a chain without correlation context
    #   CMDx::Correlator.clear  # No correlation ID set
    #   chain = Chain.new
    #   chain.id  # => "018c2b95-b764-7615-a924-cc5b910ed1e5" (generated UUID)
    #
    # @example Creating a chain with initial results
    #   existing_results = [result1, result2]
    #   chain = Chain.new(results: existing_results)
    #   chain.results.size  # => 2
    #
    # @example Block-based correlation context
    #   CMDx::Correlator.use("batch-operation") do
    #     chain = Chain.new
    #     chain.id  # => "batch-operation" (from correlation context)
    #   end
    def initialize(attributes = {})
      @id      = attributes[:id] || CMDx::Correlator.id || CMDx::Correlator.generate
      @results = Array(attributes[:results])
    end

    # Freezes the chain and ensures first result is memoized.
    #
    # Ensures the first result is cached before freezing to prevent
    # issues with delegation after the object becomes immutable.
    #
    # @return [Chain] The frozen chain instance
    #
    # @example
    #   chain.freeze
    #   chain.frozen?  # => true
    def freeze
      first_result
      super
    end

    # Gets the index of a specific result within this chain.
    #
    # Delegates to the results array to find the index of a given result,
    # enabling position tracking within the execution sequence.
    #
    # @param result [CMDx::Result] The result to find the index for
    # @return [Integer, nil] The zero-based index or nil if not found
    #
    # @example
    #   chain.index(result)  # => 0 for first result, 1 for second, etc.
    #
    # @note This method is delegated from the results array via __cmdx_attr_delegator
    def index(result)
      results.index(result)
    end

    # Gets the execution state of the chain.
    #
    # Delegates to the first result's state, representing the overall
    # execution state of the chain based on the primary task.
    #
    # @return [String] The execution state (initialized, executing, complete, interrupted)
    #
    # @example
    #   chain.state  # => "complete"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def state
      first_result&.state
    end

    # Gets the execution status of the chain.
    #
    # Delegates to the first result's status, representing the overall
    # execution outcome of the chain based on the primary task.
    #
    # @return [String] The execution status (success, skipped, failed)
    #
    # @example
    #   chain.status  # => "success"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def status
      first_result&.status
    end

    # Gets the execution outcome of the chain.
    #
    # Delegates to the first result's outcome, representing the final
    # outcome of the chain based on the primary task.
    #
    # @return [String] The execution outcome
    #
    # @example
    #   chain.outcome  # => "success"
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def outcome
      first_result&.outcome
    end

    # Gets the total runtime of the chain.
    #
    # Delegates to the first result's runtime, representing the execution
    # time of the primary task in the chain.
    #
    # @return [Float] Runtime in seconds
    #
    # @example
    #   chain.runtime  # => 0.5
    #
    # @note This method is delegated from the first result via __cmdx_attr_delegator
    def runtime
      first_result&.runtime
    end

    # Converts the chain to a hash representation.
    #
    # Serializes the chain and all its results into a structured hash
    # suitable for logging, debugging, and data interchange.
    #
    # @return [Hash] Structured hash representation of the chain
    #
    # @example
    #   chain.to_h
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
      ChainSerializer.call(self)
    end
    alias to_a to_h

    # Converts the chain to a string representation for inspection.
    #
    # Creates a comprehensive, human-readable summary of the chain including
    # all task results with formatted headers and footers.
    #
    # @return [String] Formatted chain summary with task details
    #
    # @example
    #   chain.to_s
    #   # => "
    #   #   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   ProcessOrderTask: index=0 state=complete status=success ...
    #   #   SendEmailTask: index=1 state=complete status=success ...
    #   #
    #   #   ================================================
    #   #   state: complete | status: success | outcome: success | runtime: 0.5
    #   #   "
    def to_s
      ChainInspector.call(self)
    end

    private

    # Gets the first result in the chain with memoization.
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

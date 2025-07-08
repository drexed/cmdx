# frozen_string_literal: true

module CMDx
  # Thread-local chain that tracks task execution results within a correlation context.
  #
  # A Chain represents a sequence of task executions that are logically related,
  # typically within the same request or operation flow. It provides thread-local
  # storage to ensure that tasks executing in the same thread share the same chain
  # while maintaining isolation across different threads.
  #
  # @example Basic usage with automatic chain creation
  #   # Chain is automatically created when first task runs
  #   result1 = MyTask.call(data: "first")
  #   result2 = MyTask.call(data: "second")
  #
  #   result1.chain.id == result2.chain.id  #=> true
  #   result1.index                         #=> 0
  #   result2.index                         #=> 1
  #
  # @example Using custom chain ID
  #   chain = CMDx::Chain.new(id: "custom-correlation-123")
  #   CMDx::Chain.current = chain
  #
  #   result = MyTask.call(data: "test")
  #   result.chain.id  #=> "custom-correlation-123"
  #
  # @example Thread isolation
  #   # Each thread gets its own chain
  #   Thread.new do
  #     result = MyTask.call(data: "thread1")
  #     result.chain.id  #=> unique ID for this thread
  #   end
  #
  #   Thread.new do
  #     result = MyTask.call(data: "thread2")
  #     result.chain.id  #=> different unique ID
  #   end
  #
  # @example Temporary chain context
  #   CMDx::Chain.use(id: "temp-correlation") do
  #     result = MyTask.call(data: "test")
  #     result.chain.id  #=> "temp-correlation"
  #   end
  #   # Original chain is restored after block
  #
  # @see CMDx::Correlator
  # @since 1.0.0
  class Chain

    # Thread-local storage key for the current chain
    THREAD_KEY = :cmdx_correlation_chain

    __cmdx_attr_delegator :index, :first, :last, :size,
                          to: :results
    __cmdx_attr_delegator :state, :status, :outcome, :runtime,
                          to: :first

    # @!attribute [r] id
    #   @return [String] the unique identifier for this chain
    attr_reader :id

    # @!attribute [r] results
    #   @return [Array<CMDx::Result>] the collection of task results in this chain
    attr_reader :results

    # Creates a new chain instance.
    #
    # @param attributes [Hash] configuration options for the chain
    # @option attributes [String] :id custom identifier for the chain.
    #   If not provided, uses the current correlator ID or generates a new UUID.
    #
    # @example Create chain with default ID
    #   chain = CMDx::Chain.new
    #   chain.id  #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
    #
    # @example Create chain with custom ID
    #   chain = CMDx::Chain.new(id: "user-session-123")
    #   chain.id  #=> "user-session-123"
    def initialize(attributes = {})
      @id      = attributes[:id] || CMDx::Correlator.id || CMDx::Correlator.generate
      @results = []
    end

    class << self

      # Returns the current thread-local chain.
      #
      # @return [CMDx::Chain, nil] the chain for the current thread, or nil if none exists
      #
      # @example
      #   CMDx::Chain.current  #=> nil (no chain set)
      #
      #   MyTask.call(data: "test")
      #   CMDx::Chain.current  #=> #<CMDx::Chain:0x... @id="018c2b95...">
      def current
        Thread.current[THREAD_KEY]
      end

      # Sets the current thread-local chain.
      #
      # @param chain [CMDx::Chain, nil] the chain to set for the current thread
      # @return [CMDx::Chain, nil] the chain that was set
      #
      # @example
      #   chain = CMDx::Chain.new(id: "custom-id")
      #   CMDx::Chain.current = chain
      #   CMDx::Chain.current.id  #=> "custom-id"
      def current=(chain)
        Thread.current[THREAD_KEY] = chain
      end

      # Clears the current thread-local chain.
      #
      # @return [nil]
      #
      # @example
      #   CMDx::Chain.current  #=> #<CMDx::Chain:0x...>
      #   CMDx::Chain.clear
      #   CMDx::Chain.current  #=> nil
      def clear
        Thread.current[THREAD_KEY] = nil
      end

      # Adds a result to the current chain, creating a new chain if none exists.
      #
      # This method is typically called internally by the task execution framework
      # and should not be used directly in application code.
      #
      # @param result [CMDx::Result] the task result to add to the chain
      # @return [CMDx::Chain] the chain containing the result
      #
      # @api private
      def build(result)
        raise TypeError, "must be a Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

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

  end
end

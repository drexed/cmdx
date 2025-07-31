# frozen_string_literal: true

module CMDx
  # Manages execution chains for task results with thread-local storage support.
  #
  # Chain provides a mechanism to track and correlate multiple task executions
  # within a single logical operation. It maintains a collection of results
  # and provides thread-local storage for tracking the current execution chain.
  # The chain automatically delegates common methods to its results collection
  # and the first result for convenient access to execution state.
  class Chain

    THREAD_KEY = :cmdx_correlation_chain

    cmdx_attr_delegator :index, :first, :last, :size,
                        to: :results
    cmdx_attr_delegator :state, :status, :outcome, :runtime,
                        to: :first

    # @return [String] the unique identifier for this chain
    attr_reader :id

    # @return [Array<CMDx::Result>] the collection of task results in this chain
    attr_reader :results

    # Creates a new execution chain with optional attributes.
    #
    # @param attributes [Hash] optional attributes for chain initialization
    # @option attributes [String] :id custom chain identifier, defaults to current correlation ID or generates new one
    #
    # @return [Chain] the newly created chain instance
    #
    # @example Create a chain with default ID
    #   chain = CMDx::Chain.new
    #   chain.id #=> "generated-uuid"
    #
    # @example Create a chain with custom ID
    #   chain = CMDx::Chain.new(id: "custom-123")
    #   chain.id #=> "custom-123"
    def initialize(attributes = {})
      @id      = attributes[:id] || CMDx::Correlator.id || CMDx::Correlator.generate
      @results = []
    end

    class << self

      # Gets the current execution chain from thread-local storage.
      #
      # @return [Chain, nil] the current chain or nil if none is set
      #
      # @example Access current chain
      #   chain = CMDx::Chain.current
      #   chain.id if chain #=> "current-chain-id"
      def current
        Thread.current[THREAD_KEY]
      end

      # Sets the current execution chain in thread-local storage.
      #
      # @param chain [Chain, nil] the chain to set as current
      #
      # @return [Chain, nil] the chain that was set
      #
      # @example Set current chain
      #   new_chain = CMDx::Chain.new
      #   CMDx::Chain.current = new_chain
      #   CMDx::Chain.current.id #=> new_chain.id
      def current=(chain)
        Thread.current[THREAD_KEY] = chain
      end

      # Clears the current execution chain from thread-local storage.
      #
      # @return [nil] always returns nil
      #
      # @example Clear current chain
      #   CMDx::Chain.clear
      #   CMDx::Chain.current #=> nil
      def clear
        Thread.current[THREAD_KEY] = nil
      end

      # Builds or extends the current execution chain with a new result.
      #
      # @param result [CMDx::Result] the result to add to the chain
      #
      # @return [Chain] the current chain with the result added
      #
      # @raise [TypeError] if result is not a Result instance
      #
      # @example Build chain with result
      #   task = MyTask.new
      #   result = CMDx::Result.new(task)
      #   chain = CMDx::Chain.build(result)
      #   chain.results.size #=> 1
      def build(result)
        raise TypeError, "must be a Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

    end

    # Converts the chain to a hash representation using the serializer.
    #
    # @return [Hash] serialized hash representation of the chain
    #
    # @example Convert to hash
    #   chain.to_h #=> { id: "abc123", results: [...], state: "complete" }
    def to_h
      ChainSerializer.call(self)
    end
    alias to_a to_h

    # Converts the chain to a formatted string representation.
    #
    # @return [String] formatted string representation of the chain
    #
    # @example Convert to string
    #   puts chain.to_s
    #   # chain: abc123
    #   # ===================
    #   # {...}
    #   # ===================
    #   # state: complete | status: success | outcome: success | runtime: 0.001
    def to_s
      ChainInspector.call(self)
    end

  end
end

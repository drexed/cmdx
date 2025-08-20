# frozen_string_literal: true

module CMDx
  # Manages a collection of task execution results in a thread-safe manner.
  # Chains provide a way to track related task executions and their outcomes
  # within the same execution context.
  class Chain

    extend Forwardable

    THREAD_KEY = :cmdx_chain

    attr_reader :id, :results

    def_delegators :results, :index, :first, :last, :size
    def_delegators :first, :state, :status, :outcome, :runtime

    # Creates a new chain with a unique identifier and empty results collection.
    #
    # @return [Chain] A new chain instance
    def initialize
      @id = Identifier.generate
      @results = []
    end

    class << self

      # Retrieves the current chain for the current thread.
      #
      # @return [Chain, nil] The current chain or nil if none exists
      #
      # @example
      #   chain = Chain.current
      #   if chain
      #     puts "Current chain: #{chain.id}"
      #   end
      def current
        Thread.current[THREAD_KEY]
      end

      # Sets the current chain for the current thread.
      #
      # @param chain [Chain] The chain to set as current
      #
      # @return [Chain] The set chain
      #
      # @example
      #   Chain.current = my_chain
      def current=(chain)
        Thread.current[THREAD_KEY] = chain
      end

      # Clears the current chain for the current thread.
      #
      # @return [nil] Always returns nil
      #
      # @example
      #   Chain.clear
      def clear
        Thread.current[THREAD_KEY] = nil
      end

      # Builds or extends the current chain by adding a result.
      # Creates a new chain if none exists, otherwise appends to the current one.
      #
      # @param result [Result] The task execution result to add
      #
      # @return [Chain] The current chain (newly created or existing)
      #
      # @raise [TypeError] If result is not a CMDx::Result instance
      #
      # @example
      #   result = task.execute
      #   chain = Chain.build(result)
      #   puts "Chain size: #{chain.size}"
      def build(result)
        raise TypeError, "must be a CMDx::Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

    end

    # Converts the chain to a hash representation.
    #
    # @return [Hash] Hash containing chain id and serialized results
    #
    # @option return [String] :id The chain identifier
    #
    # @option return [Array<Hash>] :results Array of result hashes
    #
    # @example
    #   chain_hash = chain.to_h
    #   puts chain_hash[:id]
    #   puts chain_hash[:results].size
    def to_h
      {
        id: id,
        results: results.map(&:to_h)
      }
    end

    # Converts the chain to a string representation.
    #
    # @return [String] Formatted string representation of the chain
    #
    # @example
    #   puts chain.to_s
    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end

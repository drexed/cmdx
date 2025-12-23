# frozen_string_literal: true

module CMDx
  # Manages a collection of task execution results in a thread-safe manner.
  # Chains provide a way to track related task executions and their outcomes
  # within the same execution context.
  class Chain

    extend Forwardable

    # @rbs THREAD_KEY: Symbol
    THREAD_KEY = :cmdx_chain

    # Returns the unique identifier for this chain.
    #
    # @return [String] The chain identifier
    #
    # @example
    #   chain.id # => "abc123xyz"
    #
    # @rbs @id: String
    attr_reader :id

    # Returns the collection of execution results in this chain.
    #
    # @return [Array<Result>] Array of task results
    #
    # @example
    #   chain.results # => [#<Result>, #<Result>]
    #
    # @rbs @results: Array[Result]
    attr_reader :results

    def_delegators :results, :index, :first, :last, :size
    def_delegators :first, :state, :status, :outcome, :runtime

    # Creates a new chain with a unique identifier and empty results collection.
    #
    # @return [Chain] A new chain instance
    #
    # @rbs () -> void
    def initialize(dry_run: false)
      @id = Identifier.generate
      @results = []
      @dry_run = !!dry_run
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
      #
      # @rbs () -> Chain?
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
      #
      # @rbs (Chain chain) -> Chain
      def current=(chain)
        Thread.current[THREAD_KEY] = chain
      end

      # Clears the current chain for the current thread.
      #
      # @return [nil] Always returns nil
      #
      # @example
      #   Chain.clear
      #
      # @rbs () -> nil
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
      #
      # @rbs (Result result) -> Chain
      def build(result, dry_run: false)
        raise TypeError, "must be a CMDx::Result" unless result.is_a?(Result)

        self.current ||= new(dry_run:)
        current.results << result
        current
      end

    end

    # Returns whether the chain is running in dry-run mode.
    #
    # @return [Boolean] Whether the chain is running in dry-run mode
    #
    # @example
    #   chain.dry_run? # => true
    #
    # @rbs () -> bool
    def dry_run?
      !!@dry_run
    end

    # Converts the chain to a hash representation.
    #
    # @option return [String] :id The chain identifier
    # @option return [Array<Hash>] :results Array of result hashes
    #
    # @return [Hash] Hash containing chain id and serialized results
    #
    # @example
    #   chain_hash = chain.to_h
    #   puts chain_hash[:id]
    #   puts chain_hash[:results].size
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      {
        id:,
        dry_run: dry_run?,
        results: results.map(&:to_h)
      }
    end

    # Converts the chain to a string representation.
    #
    # @return [String] Formatted string representation of the chain
    #
    # @example
    #   puts chain.to_s
    #
    # @rbs () -> String
    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end

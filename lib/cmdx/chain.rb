# frozen_string_literal: true

module CMDx
  # Ordered collection of {Result}s produced by a top-level task and any nested
  # tasks it triggers. A Chain is stored per-fiber so concurrent workflows
  # (see Pipeline parallel strategy) each get their own. The root Runtime
  # clears the chain on teardown.
  class Chain

    include Enumerable

    # Fiber-local storage key used by {.current}/{.current=}/{.clear}.
    STORAGE_KEY = :cmdx_chain

    class << self

      # @return [Chain, nil] the chain active on the current fiber, or nil outside execution
      def current
        Fiber[STORAGE_KEY]
      end

      # Installs `chain` as the active chain on the current fiber.
      # @param chain [Chain, nil]
      # @return [Chain, nil]
      def current=(chain)
        Fiber[STORAGE_KEY] = chain
      end

      # Clears the fiber-local chain reference.
      # @return [nil]
      def clear
        Fiber[STORAGE_KEY] = nil
      end

    end

    attr_reader :xid, :id

    # @param xid [String, nil] external correlation id (e.g. Rails `request_id`)
    #   shared across every {Result} in this chain. Resolved once by Runtime
    #   from {Settings#correlation_id} (a callable) when the root chain is
    #   created.
    def initialize(xid = nil)
      @xid     = xid
      @id      = SecureRandom.uuid_v7
      @mutex   = Mutex.new
      @results = []
      @root    = nil
    end

    # @return [Array<Result>] snapshot of the results stored in this chain.
    #   While the chain is mutable a dup is returned so callers cannot mutate
    #   internal state and see consistent ordering despite parallel pushes;
    #   after {#freeze} the actual frozen array is returned to preserve
    #   `Array#frozen?` semantics.
    def results
      @mutex.synchronize { @results.frozen? ? @results : @results.dup }
    end

    # Appends `result` to the chain. Thread-safe to support parallel pipelines.
    #
    # @param result [Result]
    # @return [Chain] self for chaining
    def push(result)
      @mutex.synchronize do
        @results << result
        @root = result if @root.nil? && result.respond_to?(:root?) && result.root?
      end
      self
    end
    alias << push

    # Prepends `result` to the chain. Thread-safe to support parallel pipelines.
    #
    # @param result [Result]
    # @return [Chain] self for chaining
    def unshift(result)
      @mutex.synchronize do
        @results.unshift(result)
        @root = result if result.respond_to?(:root?) && result.root?
      end
      self
    end

    # @param result [Result]
    # @return [Integer, nil] zero-based position of `result`, or nil when absent
    def index(result)
      @mutex.synchronize { @results.index(result) }
    end

    # @return [Result, nil] the most recently appended result
    def last
      @mutex.synchronize { @results.last }
    end

    # @return [Result, nil] the root result, or nil when absent
    def root
      @mutex.synchronize do
        @root || @results.find { |r| r.respond_to?(:root?) && r.root? }
      end
    end

    # @return [String, nil] the state of the root result, or nil when absent
    def state
      root&.state
    end

    # @return [String, nil] the status of the root result, or nil when absent
    def status
      root&.status
    end

    # @return [Boolean]
    def empty?
      @mutex.synchronize { @results.empty? }
    end

    # @return [Integer]
    def size
      @mutex.synchronize { @results.size }
    end

    # @yield [Result] each result in insertion order
    # @return [Enumerator, Chain]
    def each(&)
      results.each(&)
    end

    # Freezes the chain and its results. Called by Runtime teardown.
    #
    # @return [Chain] self
    def freeze
      @mutex.synchronize { @results.freeze }
      super
    end

  end
end

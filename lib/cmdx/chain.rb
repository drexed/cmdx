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

    attr_reader :xid, :id, :results

    # @param xid [String, nil] external correlation id (e.g. Rails `request_id`)
    #   shared across every {Result} in this chain. Resolved once by Runtime
    #   from {Settings#correlation_id} (a callable) when the root chain is
    #   created.
    def initialize(xid = nil)
      @xid     = xid
      @id      = SecureRandom.uuid_v7
      @mutex   = Mutex.new
      @results = []
    end

    # Appends `result` to the chain. Thread-safe to support parallel pipelines.
    #
    # @param result [Result]
    # @return [Chain] self for chaining
    def push(result)
      @mutex.synchronize { @results << result }
      self
    end
    alias << push

    # Prepends `result` to the chain. Thread-safe to support parallel pipelines.
    #
    # @param result [Result]
    # @return [Chain] self for chaining
    def unshift(result)
      @mutex.synchronize { @results.unshift(result) }
      self
    end

    # @param result [Result]
    # @return [Integer, nil] zero-based position of `result`, or nil when absent
    def index(result)
      @results.index(result)
    end

    # @return [Result, nil] the most recently appended result
    def last
      @results.last
    end

    # @return [Result, nil] the root result, or nil when absent
    def root
      @results.find(&:root?)
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
      @results.empty?
    end

    # @return [Integer]
    def size
      @results.size
    end

    # @yield [Result] each result in insertion order
    # @return [Enumerator, Chain]
    def each(&)
      @results.each(&)
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

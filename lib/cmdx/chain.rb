# frozen_string_literal: true

module CMDx
  # Thread/fiber-safe ordered list of Results for nested task executions.
  # The outermost task owns the chain; nested tasks push to it.
  class Chain

    extend Forwardable

    # @rbs STORAGE_KEY: Symbol
    STORAGE_KEY = :cmdx_chain

    # @return [String]
    attr_reader :id

    # @return [Array<Result>]
    attr_reader :results

    # @return [Boolean]
    attr_reader :dry_run

    def_delegators :results, :first, :last, :size, :empty?

    # @rbs (?dry_run: bool) -> void
    def initialize(dry_run: false)
      @mutex = Mutex.new
      @id = Identifier.generate
      @results = []
      @dry_run = !!dry_run
    end

    # Retrieves the current chain for this fiber/thread.
    #
    # @return [Chain, nil]
    #
    # @rbs () -> Chain?
    def self.current
      if Fiber.respond_to?(:[])
        Fiber[STORAGE_KEY]
      else
        Thread.current[STORAGE_KEY]
      end
    end

    # Sets the current chain for this fiber/thread.
    #
    # @param chain [Chain, nil]
    #
    # @rbs (Chain? chain) -> void
    def self.current=(chain)
      if Fiber.respond_to?(:[]=)
        Fiber[STORAGE_KEY] = chain
      else
        Thread.current[STORAGE_KEY] = chain
      end
    end

    # Clears the current chain.
    #
    # @rbs () -> void
    def self.clear
      self.current = nil
    end

    # Thread-safe push of a result.
    #
    # @param result [Result]
    #
    # @rbs (Result result) -> void
    def push(result)
      @mutex.synchronize { @results << result }
    end

    # @return [Integer]
    #
    # @rbs () -> Integer
    def next_index
      @mutex.synchronize { @results.size }
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def dry_run?
      @dry_run
    end

    # @return [self]
    #
    # @rbs () -> self
    def freeze
      @results.freeze
      super
    end

  end
end

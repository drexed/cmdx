# frozen_string_literal: true

module CMDx
  # Thread and fiber safe collection of task execution results.
  # Tracks related task executions within the same execution context
  # using Fiber.storage (Ruby 3.2+) with Thread.current fallback.
  class Chain

    # @rbs CONCURRENCY_KEY: Symbol
    CONCURRENCY_KEY = :cmdx_chain

    # @return [String] unique chain identifier
    #
    # @rbs @id: String
    attr_reader :id

    # @return [Array<Result>] ordered execution results
    #
    # @rbs @results: Array[Result]
    attr_reader :results

    # @rbs (?dry_run: bool) -> void
    def initialize(dry_run: false)
      @mutex = Mutex.new
      @id = Identifier.generate
      @results = []
      @dry_run = !!dry_run
    end

    class << self

      # @return [Chain, nil] current chain for this execution context
      #
      # @rbs () -> Chain?
      def current
        thread_or_fiber[CONCURRENCY_KEY]
      end

      # @rbs (Chain chain) -> Chain
      def current=(chain)
        thread_or_fiber[CONCURRENCY_KEY] = chain
      end

      # @rbs () -> nil
      def clear
        thread_or_fiber[CONCURRENCY_KEY] = nil
      end

      # Builds or extends the current chain by adding a result.
      #
      # @param result [Result] the result to add
      # @param dry_run [Boolean] whether this is a dry run
      #
      # @return [Chain] the current chain
      #
      # @rbs (Result result, ?dry_run: bool) -> Chain
      def build(result, dry_run: false)
        self.current ||= new(dry_run:)
        current.push(result)
        current
      end

      private

      # @rbs () -> Hash
      if Fiber.respond_to?(:storage)
        def thread_or_fiber = Fiber.storage
      else
        def thread_or_fiber = Thread.current
      end

    end

    # Thread-safe append.
    #
    # @param result [Result] the result to append
    #
    # @return [Array<Result>]
    #
    # @rbs (Result result) -> Array[Result]
    def push(result)
      @mutex.synchronize { @results << result }
    end

    # Returns the next index for a result being added.
    #
    # @return [Integer]
    #
    # @rbs () -> Integer
    def next_index
      @mutex.synchronize { @results.size }
    end

    # Thread-safe index lookup.
    #
    # @param result [Result] the result to find
    #
    # @return [Integer, nil] zero-based index
    #
    # @rbs (Result result) -> Integer?
    def index(result)
      @mutex.synchronize { @results.index(result) }
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def dry_run?
      !!@dry_run
    end

    def first = results.first
    def last = results.last
    def size = results.size

    # @rbs () -> self
    def freeze
      results.freeze
      super
    end

    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      { id:, dry_run: dry_run?, results: results.map(&:to_h) }
    end

    # @rbs () -> String
    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Thread/fiber-local execution trace that tracks related task results.
  class Chain

    extend Forwardable

    FIBER_STORAGE = Fiber.respond_to?(:[])
    UUID_V7 = SecureRandom.respond_to?(:uuid_v7)

    STORAGE_KEY = :cmdx_chain
    private_constant :STORAGE_KEY

    attr_reader :id, :results

    def_delegators :@results, :size, :first, :last, :each

    def initialize
      @id = UUID_V7 ? SecureRandom.uuid_v7 : SecureRandom.uuid
      @results = []
      @depth = 0
    end

    # Get or create the current fiber/thread-local chain.
    #
    # @return [CMDx::Chain]
    def self.current
      if FIBER_STORAGE
        Fiber[STORAGE_KEY]
      else
        Thread.current[STORAGE_KEY]
      end
    end

    # Set the current chain.
    #
    # @param chain [CMDx::Chain, nil]
    # @return [void]
    def self.current=(chain)
      if FIBER_STORAGE
        Fiber[STORAGE_KEY] = chain
      else
        Thread.current[STORAGE_KEY] = chain
      end
    end

    # Clear the current fiber/thread-local chain.
    #
    # @return [void]
    def self.clear
      self.current = nil
    end

    # Add a result to the chain.
    #
    # @param result [CMDx::Result]
    # @return [void]
    def add(result)
      result.index = @results.size
      result.chain = self
      @results << result
    end

    # Track nesting depth for outermost-task detection.
    #
    # @return [Integer]
    def enter
      @depth += 1
    end

    # @return [Integer]
    def exit
      @depth -= 1
    end

    # @return [Boolean]
    def outermost?
      @depth.zero?
    end

    # @return [Boolean]
    def dry_run?
      first&.dry_run? || false
    end

    # Delegates state from the first (outermost) result.
    # @return [String, nil]
    def state
      first&.state
    end

    # @return [String, nil]
    def status
      first&.status
    end

    # @return [String, nil]
    def outcome
      first&.outcome
    end

    def freeze
      @results.freeze
      super
    end

    def inspect
      "#<#{self.class} id=#{@id} results=#{@results.size}>"
    end

  end
end

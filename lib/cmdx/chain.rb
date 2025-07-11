# frozen_string_literal: true

module CMDx
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

    def initialize(attributes = {})
      @id      = attributes[:id] || CMDx::Correlator.id || CMDx::Correlator.generate
      @results = []
    end

    class << self

      def current
        Thread.current[THREAD_KEY]
      end

      def current=(chain)
        Thread.current[THREAD_KEY] = chain
      end

      def clear
        Thread.current[THREAD_KEY] = nil
      end

      def build(result)
        raise TypeError, "must be a Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

    end

    def to_h
      ChainSerializer.call(self)
    end
    alias to_a to_h

    def to_s
      ChainInspector.call(self)
    end

  end
end

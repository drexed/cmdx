# frozen_string_literal: true

module CMDx
  class Chain

    extend Forwardable

    THREAD_KEY = :cmdx_chain

    def_delegators :results, :index, :first, :last, :size
    def_delegators :first, :state, :status, :outcome, :runtime

    attr_reader :results

    def initialize
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

      def build!(result)
        raise TypeError, "must be a Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

    end

  end
end

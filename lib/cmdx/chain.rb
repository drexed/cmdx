# frozen_string_literal: true

module CMDx
  class Chain

    extend Forwardable

    THREAD_KEY = :cmdx_chain

    attr_reader :id, :results

    def_delegators :results, :index, :first, :last, :size
    def_delegators :first, :state, :status, :outcome, :runtime

    def initialize
      @id = Identifier.generate
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
        raise TypeError, "must be a CMDx::Result" unless result.is_a?(Result)

        self.current ||= new
        current.results << result
        current
      end

    end

    def to_h
      {
        id: id,
        results: results.map(&:to_h)
      }
    end

    def to_s
      Utils::Format.to_str(to_h)
    end

  end
end

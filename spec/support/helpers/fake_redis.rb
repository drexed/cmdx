# frozen_string_literal: true

module CMDx
  module Testing
    # Minimal Redis-compatible client for store adapter specs.
    class FakeRedis

      attr_reader :data, :ttl

      def initialize
        @data = {}
        @ttl = {}
      end

      def get(key)
        expire!(key)
        @data[key]
      end

      def set(key, value, ex: nil, nx: false, xx: false)
        expire!(key)
        present = @data.key?(key)

        return nil if nx && present
        return nil if xx && !present

        @data[key] = value
        @ttl[key] = ex if ex
        true
      end

      def incr(key)
        expire!(key)
        @data[key] = (@data[key] || 0).to_i + 1
      end

      def expire(key, seconds) # rubocop:disable Naming/PredicateMethod -- Redis EXPIRE contract
        @ttl[key] = seconds
        true
      end

      def del(key)
        existed = @data.key?(key)
        @data.delete(key)
        @ttl.delete(key)
        existed ? 1 : 0
      end

      private

      def expire!(key)
        return unless @ttl[key]

        nil
      end

    end
  end
end

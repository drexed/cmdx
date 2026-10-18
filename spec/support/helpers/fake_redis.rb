# frozen_string_literal: true

module CMDx
  module Testing
    # Minimal Redis-compatible client for store adapter specs.
    class FakeRedis

      attr_reader :data, :expiries

      def initialize
        @data = {}
        @expiries = {}
      end

      def get(key)
        expire!(key)
        @data[key]
      end

      def set(key, value, ex: nil, nx: false, xx: false)
        expire!(key)
        present = @data.key?(key)

        return if nx && present
        return if xx && !present

        @data[key] = value
        @expiries[key] = ex if ex
        true
      end

      def incr(key)
        expire!(key)
        @data[key] = (@data[key] || 0).to_i + 1
      end

      def expire(key, seconds) # rubocop:disable Naming/PredicateMethod -- Redis EXPIRE contract
        @expiries[key] = seconds
        true
      end

      def ttl(key)
        expire!(key)
        return -2 unless @data.key?(key)

        seconds = @expiries[key]
        return -1 unless seconds

        seconds
      end

      def del(key)
        existed = @data.key?(key)
        @data.delete(key)
        @expiries.delete(key)
        existed ? 1 : 0
      end

      def eval(_script, keys:, argv:)
        key = keys.first
        expected = argv.first
        return 0 unless get(key) == expected

        del(key)
      end

      private

      def expire!(key)
        return unless @expiries[key]

        nil
      end

    end
  end
end

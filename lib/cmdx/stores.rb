# frozen_string_literal: true

module CMDx
  # Key/value scratch space for idempotency keys, rate limits, circuit breakers,
  # checkpoints, and cached results. {Stores} delegates to
  # {Configuration#store}; swap the configured backend (for example
  # {Stores::Memory} or {Stores::Redis}) at boot.
  module Stores

    class << self

      # @param key [String, Symbol]
      # @return [String, nil] stored value, or `nil` when missing or expired
      # @raise [ArgumentError] when `key` is blank
      # @see Configuration#store
      def get(key)
        CMDx.configuration.store.get(key)
      end

      # @param key [String, Symbol]
      # @param value [#to_s]
      # @param ttl [Integer, nil]
      # @param nx [Boolean]
      # @param xx [Boolean]
      # @return [Boolean] whether the value was written
      # @raise [ArgumentError] when `key` is blank, `ttl` is invalid, or `nx` and `xx` are both true
      def set(key, value, ttl: nil, nx: false, xx: false)
        CMDx.configuration.store.set(key, value, ttl:, nx:, xx:)
      end

      # @param key [String, Symbol]
      # @param ttl [Integer, nil] when set, refreshes expiry on every increment
      # @return [Integer] value after increment
      # @raise [ArgumentError] when `key` is blank or `ttl` is invalid
      def incr(key, ttl: nil)
        CMDx.configuration.store.incr(key, ttl:)
      end

      # @param key [String, Symbol]
      # @param ttl [Integer, nil] unused; accepted for API symmetry with {#incr}
      # @return [Integer] value after decrement
      # @raise [ArgumentError] when `key` is blank
      def decr(key, ttl: nil)
        CMDx.configuration.store.decr(key, ttl:)
      end

      # @param key [String, Symbol]
      # @return [Integer] `1` when a key was removed, `0` otherwise
      # @raise [ArgumentError] when `key` is blank
      def del(key)
        CMDx.configuration.store.del(key)
      end

      # @param key [String, Symbol]
      # @return [Integer, nil] seconds until expiry when the backend supports
      #   {#ttl}; `nil` when the key is missing, expired, or TTL is unavailable
      # @raise [ArgumentError] when `key` is blank
      def remaining_ttl(key)
        store = CMDx.configuration.store
        return unless store.respond_to?(:ttl)

        seconds = store.ttl(key)
        seconds if seconds.is_a?(Integer) && seconds.positive?
      end

      # @param key [String, Symbol]
      # @return [String]
      # @raise [ArgumentError] when `key` is blank
      # @api private
      def key!(key)
        str = key.to_s
        raise ArgumentError, "store key must be non-empty" if str.empty?

        str
      end

      # @param ttl [Integer]
      # @return [Integer]
      # @raise [ArgumentError] when `ttl` is not a positive Integer
      # @api private
      def ttl!(ttl)
        raise ArgumentError, "store ttl must be a positive Integer (got #{ttl.inspect})" unless ttl.is_a?(Integer) && ttl.positive?

        ttl
      end

      # @param nx [Boolean]
      # @param xx [Boolean]
      # @return [void]
      # @raise [ArgumentError] when both flags are true
      # @api private
      def nx_xx!(nx, xx)
        return unless nx && xx

        raise ArgumentError, "store set cannot use nx and xx together"
      end

    end

  end
end

require_relative "stores/memory"
require_relative "stores/redis"

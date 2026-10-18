# frozen_string_literal: true

module CMDx
  module Stores
    # Delegates to a Redis-compatible client (`redis-rb`, `MockRedis`, etc.).
    # Keys are prefixed to avoid collisions with unrelated application data.
    #
    # The client must respond to `get`, `set`, `incr`, `expire`, `ttl`, and `del`.
    class Redis

      # @param redis [#get, #set, #incr, #expire, #del] backing client
      # @param namespace [String] prepended to every key (trailing `:` added when missing)
      def initialize(redis:, namespace: "cmdx:store")
        @redis = redis
        @namespace = namespace.end_with?(":") ? namespace : "#{namespace}:"
      end

      # @param key [String, Symbol]
      # @return [String, nil]
      def get(key)
        @redis.get(prefixed(key))
      end

      # @param key [String, Symbol]
      # @param value [#to_s]
      # @param ttl [Integer, nil]
      # @param nx [Boolean]
      # @param xx [Boolean]
      # @return [Boolean]
      # @raise [ArgumentError] when `nx` and `xx` are both true, or `ttl` is invalid
      def set(key, value, ttl: nil, nx: false, xx: false) # rubocop:disable Naming/PredicateMethod -- Redis SET contract
        key = prefixed(key)
        ttl = Stores.ttl!(ttl) if ttl
        Stores.nx_xx!(nx, xx)

        options = {}
        options[:ex] = ttl if ttl
        options[:nx] = true if nx
        options[:xx] = true if xx

        if options.empty?
          @redis.set(key, value.to_s)
          true
        else
          !!@redis.set(key, value.to_s, **options)
        end
      end

      # @param key [String, Symbol]
      # @param ttl [Integer, nil]
      # @return [Integer]
      # @raise [ArgumentError] when `ttl` is invalid
      def incr(key, ttl: nil)
        key = prefixed(key)
        ttl = Stores.ttl!(ttl) if ttl

        count = @redis.incr(key)
        @redis.expire(key, ttl) if ttl
        count
      end

      # @param key [String, Symbol]
      # @return [Integer, nil] seconds until expiry, or `nil` when missing or expired
      def ttl(key)
        key = prefixed(key)
        seconds = @redis.ttl(key)
        seconds if seconds.is_a?(Integer) && seconds.positive?
      end

      # @param key [String, Symbol]
      # @return [Integer]
      def decr(key, ttl: nil)
        key = prefixed(key)
        Stores.ttl!(ttl) if ttl

        @redis.decr(key)
      end

      # @param key [String, Symbol]
      # @return [Integer]
      def del(key)
        @redis.del(prefixed(key))
      end

      private

      def prefixed(key)
        "#{@namespace}#{Stores.key!(key)}"
      end

    end
  end
end

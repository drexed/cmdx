# frozen_string_literal: true

module CMDx
  module Stores
    # Process-local key/value store with optional per-key TTL. Thread-safe via
    # an internal mutex. Suitable for tests and single-process dev; not shared
    # across workers.
    class Memory

      def initialize
        @mutex = Mutex.new
        @entries = {}
      end

      # @param key [String, Symbol]
      # @return [String, nil] stored value, or `nil` when missing or expired
      def get(key)
        key = Stores.key!(key)
        @mutex.synchronize do
          entry = @entries[key]
          return nil unless entry
          return nil if expired?(entry)

          entry[:value]
        end
      end

      # @param key [String, Symbol]
      # @param value [#to_s]
      # @param ttl [Integer, nil] seconds until expiry (`nil` = no expiry)
      # @param nx [Boolean] set only when the key is absent
      # @param xx [Boolean] set only when the key is present
      # @return [Boolean] whether the value was written
      # @raise [ArgumentError] when `nx` and `xx` are both true, or `ttl` is invalid
      def set(key, value, ttl: nil, nx: false, xx: false)
        key = Stores.key!(key)
        ttl = Stores.ttl!(ttl) if ttl
        Stores.nx_xx!(nx, xx)

        expires_at = ttl ? monotonic_now + ttl : nil
        @mutex.synchronize do
          entry = @entries[key]
          present = entry && !expired?(entry)

          return false if nx && present
          return false if xx && !present

          @entries[key] = { value: value.to_s, expires_at: }
          true
        end
      end

      # @param key [String, Symbol]
      # @param ttl [Integer, nil] when set, expiry is applied only if the key is
      #   created by this call (count becomes `1`)
      # @return [Integer] value after increment
      # @raise [ArgumentError] when `ttl` is invalid
      def incr(key, ttl: nil)
        key = Stores.key!(key)
        ttl = Stores.ttl!(ttl) if ttl

        @mutex.synchronize do
          entry = @entries[key]
          if entry && expired?(entry)
            @entries.delete(key)
            entry = nil
          end

          count = entry ? entry[:value].to_i + 1 : 1
          expires_at = entry&.fetch(:expires_at, nil)
          expires_at = monotonic_now + ttl if ttl && count == 1

          @entries[key] = { value: count.to_s, expires_at: }
          count
        end
      end

      # @param key [String, Symbol]
      # @return [Integer] value after decrement (floors at `0`, removing the key)
      # @raise [ArgumentError] when `ttl` is invalid (only when `ttl` is passed)
      def decr(key, ttl: nil)
        key = Stores.key!(key)
        Stores.ttl!(ttl) if ttl

        @mutex.synchronize do
          entry = @entries[key]
          if entry && expired?(entry)
            @entries.delete(key)
            entry = nil
          end

          count = entry ? entry[:value].to_i : 0
          count = count.positive? ? count - 1 : 0
          expires_at = entry&.fetch(:expires_at, nil)

          if count.zero?
            @entries.delete(key)
          else
            @entries[key] = { value: count.to_s, expires_at: }
          end

          count
        end
      end

      # @param key [String, Symbol]
      # @return [Integer] `1` when a key was removed, `0` otherwise
      def del(key)
        key = Stores.key!(key)
        @mutex.synchronize do
          @entries.delete(key) ? 1 : 0
        end
      end

      private

      def expired?(entry)
        expires_at = entry[:expires_at]
        expires_at && monotonic_now >= expires_at
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

    end
  end
end

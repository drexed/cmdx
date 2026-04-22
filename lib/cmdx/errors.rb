# frozen_string_literal: true

module CMDx
  # Per-task container of validation / coercion / output errors. Each key maps
  # to a deduplicating Set of messages. A non-empty Errors forces Runtime to
  # throw a failed signal (`signal_errors!`). Frozen on teardown by Runtime.
  class Errors

    include Enumerable

    attr_reader :messages

    def initialize
      @messages = {}
    end

    # Adds `message` under `key`. Duplicate messages are silently dropped.
    #
    # @param key [Symbol]
    # @param message [String]
    # @return [Set<String>] the set of messages now stored under `key`
    def add(key, message)
      (messages[key] ||= Set.new) << message
    end
    alias []= add

    # Copies every message from `other` into self. Existing messages are
    # preserved and duplicates (same key + message) are silently dropped by
    # the underlying Set. Accepts any object that responds to `#to_hash`
    # returning `Hash{Symbol => Enumerable<String>}` — typically another
    # {Errors} instance.
    #
    # @param other [Errors, #to_hash]
    # @return [void]
    # @example Combine validation errors from a nested task
    #   parent.errors.merge!(child.result.errors)
    def merge!(other)
      other.to_hash.each do |key, messages|
        messages.each { |message| add(key, message) }
      end
    end

    # @param key [Symbol]
    # @return [Array<String>] messages for `key`, or a frozen empty array
    def [](key)
      messages[key]&.to_a || EMPTY_ARRAY
    end

    # @param key [Symbol]
    # @param message [String]
    # @return [Boolean] true when `message` is recorded under `key`
    def added?(key, message)
      !!messages[key]&.include?(message)
    end

    # @param key [Symbol]
    # @return [Boolean]
    def key?(key)
      messages.key?(key)
    end
    alias for? key?

    # @return [Array<Symbol>] keys with at least one message
    def keys
      messages.keys
    end

    # @return [Boolean]
    def empty?
      messages.empty?
    end

    # @return [Integer] number of keyed entries
    def size
      messages.size
    end

    # @return [Integer] total messages across all keys
    def count
      messages.each_value.sum(&:size)
    end

    # @yield [key, set] each `[key, Set<String>]` pair
    # @return [Errors, Enumerator]
    def each(&)
      messages.each(&)
    end

    # @yield [Symbol]
    # @return [Errors, Enumerator]
    def each_key(&)
      messages.each_key(&)
    end

    # @yield [Set<String>]
    # @return [Errors, Enumerator]
    def each_value(&)
      messages.each_value(&)
    end

    # @param key [Symbol]
    # @return [Set<String>, nil] the removed set, or nil when absent
    def delete(key)
      messages.delete(key)
    end

    # @return [Hash{Symbol => Set<String>}] empties the container
    def clear
      messages.clear
    end

    # @return [Hash{Symbol => Array<String>}] messages prefixed with their key
    #   (e.g. `{ name: ["name is required"] }`)
    def full_messages
      messages.each_with_object({}) do |(key, set), hash|
        hash[key] = set.map { |message| "#{key} #{message}" }
      end
    end

    # @return [Hash{Symbol => Array<String>}] raw messages as arrays
    def to_h
      messages.transform_values(&:to_a)
    end

    # @param full [Boolean] when true return {#full_messages}, otherwise {#to_h}
    # @return [Hash{Symbol => Array<String>}]
    def to_hash(full = false)
      full ? full_messages : to_h
    end

    # @return [String] all full messages joined with `". "`, suitable as a
    #   fail reason
    def to_s
      full_messages.values.flatten.join(". ")
    end

    # Pattern-matching support for `case errors in {...}`.
    #
    # @param keys [Array<Symbol>, nil] restrict the returned hash to these keys
    # @return [Hash{Symbol => Array<String>}]
    #
    # @example
    #   case task.errors
    #   in { name: [_, *] } then handle_name_errors(task)
    #   end
    def deconstruct_keys(keys)
      keys.nil? ? to_h : to_h.slice(*keys)
    end

    # Pattern-matching support for `case errors in [...]`.
    #
    # @return [Array<Array(Symbol, Array<String>)>]
    def deconstruct
      to_h.to_a
    end

    # Freezes the container and every message set. Called by Runtime teardown.
    #
    # @return [Errors] self
    def freeze
      messages.each_value(&:freeze).freeze
      super
    end

  end
end

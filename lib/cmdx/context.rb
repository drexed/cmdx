# frozen_string_literal: true

module CMDx
  # Hash-like context object for storing and accessing key-value pairs
  # during task execution. Keys are automatically symbolized.
  class Context

    # @return [Hash{Symbol => Object}] the internal data store
    #
    # @rbs @table: Hash[Symbol, untyped]
    attr_reader :table
    alias to_h table

    # @param args [Hash, Object] initial data (must respond to `to_h` or `to_hash`)
    #
    # @raise [ArgumentError] when args cannot be converted to a hash
    #
    # @rbs (untyped args) -> void
    def initialize(args = {})
      @table =
        if args.respond_to?(:to_hash)
          args.to_hash
        elsif args.respond_to?(:to_h)
          args.to_h
        else
          raise ArgumentError, "must respond to `to_h` or `to_hash`"
        end.transform_keys(&:to_sym)
    end

    # Builds a Context, reusing existing unfrozen instances when possible.
    #
    # @param context [Context, Object] source data
    #
    # @return [Context]
    #
    # @rbs (untyped context) -> Context
    def self.build(context = {})
      if context.is_a?(self) && !context.frozen?
        context
      elsif context.respond_to?(:context)
        build(context.context)
      else
        new(context)
      end
    end

    # @rbs ((String | Symbol) key) -> untyped
    def [](key)
      table[key.to_sym]
    end

    # @rbs ((String | Symbol) key, untyped value) -> untyped
    def store(key, value)
      table[key.to_sym] = value
    end
    alias []= store

    # @rbs ((String | Symbol) key, *untyped) ?{ ((String | Symbol)) -> untyped } -> untyped
    def fetch(key, ...)
      table.fetch(key.to_sym, ...)
    end

    # @rbs ((String | Symbol) key, ?untyped value) ?{ () -> untyped } -> untyped
    def fetch_or_store(key, value = nil)
      table.fetch(key.to_sym) do
        table[key.to_sym] = block_given? ? yield : value
      end
    end

    # @rbs (?untyped args) -> self
    def merge!(args = EMPTY_HASH)
      table.merge!(args.to_h.transform_keys(&:to_sym))
      self
    end
    alias merge merge!

    # @rbs ((String | Symbol) key) ?{ ((String | Symbol)) -> untyped } -> untyped
    def delete!(key, &)
      table.delete(key.to_sym, &)
    end
    alias delete delete!

    # @rbs () -> self
    def clear!
      table.clear
      self
    end
    alias clear clear!

    # @rbs (untyped other) -> bool
    def eql?(other)
      other.is_a?(self.class) && (table == other.to_h)
    end
    alias == eql?

    # @rbs ((String | Symbol) key) -> bool
    def key?(key)
      table.key?(key.to_sym)
    end

    # @rbs ((String | Symbol) key, *(String | Symbol) keys) -> untyped
    def dig(key, *keys)
      table.dig(key.to_sym, *keys)
    end

    def keys = table.keys
    def values = table.values
    def each(&) = table.each(&)
    def each_key(&) = table.each_key(&)
    def each_value(&) = table.each_value(&)
    def map(&) = table.map(&)

    # @rbs () -> String
    def to_s
      Utils::Format.to_str(to_h)
    end

    private

    # @rbs (Symbol method_name, *untyped args, **untyped) ?{ () -> untyped } -> untyped
    def method_missing(method_name, *args, **, &)
      if method_name.end_with?("=")
        store(method_name.name.chop, args.first)
      else
        table[method_name]
      end
    end

    # @rbs (Symbol method_name, ?bool include_private) -> bool
    def respond_to_missing?(method_name, include_private = false)
      key?(method_name) || method_name.end_with?("=") || super
    end

  end
end

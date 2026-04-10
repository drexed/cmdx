# frozen_string_literal: true

module CMDx
  # Symbol-keyed bag for inputs and outputs. No +method_missing+ on the hot path.
  class Context

    # @return [Hash{Symbol => Object}]
    attr_reader :table

    # @param args [Hash, #to_h]
    def initialize(args = {})
      @table =
        if args.respond_to?(:to_hash)
          args.to_hash
        elsif args.respond_to?(:to_h)
          args.to_h
        else
          raise ArgumentError, "must respond to `to_h` or `to_hash`"
        end.transform_keys(&:to_sym).dup
    end

    # @param context [Context, Hash, Object]
    # @return [Context]
    def self.build(context = {})
      return context if context.is_a?(self)

      new(context)
    end

    # @param key [Symbol, String]
    # @return [Object, nil]
    def [](key)
      @table[key.to_sym]
    end

    # @param key [Symbol, String]
    # @param value [Object]
    # @return [Object]
    def []=(key, value)
      @table[key.to_sym] = value
    end

    # @param key [Symbol, String]
    # @return [Boolean]
    def key?(key)
      @table.key?(key.to_sym)
    end

    # @param other [Hash]
    # @return [self]
    def merge!(other)
      @table.merge!(other.to_h.transform_keys(&:to_sym))
      self
    end

    # @return [Hash{Symbol => Object}]
    def to_h
      @table
    end

    # @return [void]
    def freeze
      @table.freeze
      super
    end

  end
end

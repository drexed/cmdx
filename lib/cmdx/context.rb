# frozen_string_literal: true

module CMDx
  # Symbol-keyed data bag for task inputs and outputs.
  # Supports bracket access and dynamic method access via +method_missing+.
  class Context

    extend Forwardable

    # @return [Hash{Symbol => Object}]
    #
    # @rbs @table: Hash[Symbol, untyped]
    attr_reader :table
    alias to_h table

    def_delegators :table, :keys, :values, :each, :each_key, :each_value, :map, :empty?, :size

    # Builds a Context from various input types, reusing unfrozen contexts.
    #
    # @param args [Context, Hash, nil]
    # @return [Context]
    #
    # @rbs (untyped args) -> Context
    def self.build(args = {})
      case args
      when Context then args.frozen? ? new(args.to_h) : args
      when Hash then new(args)
      when nil then new
      else
        if args.respond_to?(:context)
          ctx = args.context
          ctx.frozen? ? new(ctx.to_h) : ctx
        elsif args.respond_to?(:to_h)
          new(args.to_h)
        else
          raise ArgumentError, "cannot build Context from #{args.class}"
        end
      end
    end

    # @param data [Hash]
    #
    # @rbs (?Hash[untyped, untyped] data) -> void
    def initialize(data = {})
      @table = data.transform_keys(&:to_sym)
    end

    # @rbs (Symbol | String key) -> untyped
    def [](key)
      @table[key.to_sym]
    end

    # @rbs (Symbol | String key, untyped value) -> untyped
    def []=(key, value)
      @table[key.to_sym] = value
    end

    # @rbs (Symbol | String key, *untyped args) -> untyped
    def fetch(key, ...)
      @table.fetch(key.to_sym, ...)
    end

    # @rbs (Symbol | String key) -> bool
    def key?(key)
      @table.key?(key.to_sym)
    end
    alias has_key? key?

    # @rbs (Hash[untyped, untyped] other) -> self
    def merge!(other)
      other.each { |k, v| @table[k.to_sym] = v }
      self
    end

    # @rbs (*untyped keys) -> untyped
    def dig(*keys)
      @table.dig(*keys.map { |k| k.is_a?(String) ? k.to_sym : k })
    end

    # @return [self]
    #
    # @rbs () -> self
    def freeze
      @table.freeze
      super
    end

    # @return [String]
    #
    # @rbs () -> String
    def to_s
      @table.to_s
    end

    # @return [String]
    #
    # @rbs () -> String
    def inspect
      "#<#{self.class} #{@table.inspect}>"
    end

    private

    # @rbs (Symbol name, *untyped args) -> untyped
    def method_missing(name, *args)
      key = name.to_s
      if key.end_with?("=")
        self[key.chomp("=").to_sym] = args.first
      elsif key.end_with?("?")
        key?(key.chomp("?").to_sym)
      else
        self[name]
      end
    end

    # @rbs (Symbol name, ?bool include_private) -> bool
    def respond_to_missing?(_name, _include_private = false)
      true
    end

  end
end

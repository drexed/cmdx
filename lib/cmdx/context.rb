# frozen_string_literal: true

module CMDx
  # Data container for task inputs, intermediate values, and outputs.
  # Wraps a Hash internally for fast lookups with dynamic method access.
  class Context

    # Build a Context from various input types.
    #
    # @param input [Hash, Context, Result, Task, nil] the input to build from
    # @return [CMDx::Context]
    # @raise [ArgumentError] if input can't be converted to a hash
    def self.build(input = nil)
      case input
      when nil          then new
      when Context      then input.frozen? ? new(input.to_h) : input
      when Hash         then new(input)
      else
        if input.respond_to?(:context)
          ctx = input.context
          ctx.frozen? ? new(ctx.to_h) : ctx
        elsif input.respond_to?(:to_h)
          new(input.to_h)
        else
          raise ArgumentError, "Cannot build Context from #{input.class}"
        end
      end
    end

    def initialize(data = {})
      @data = {}
      data.each { |k, v| @data[k.to_sym] = v }
    end

    # @return [Object, nil]
    def [](key)
      @data[key.to_sym]
    end

    # @return [Object]
    def []=(key, value)
      @data[key.to_sym] = value
    end

    # @param key [Symbol, String]
    # @param default [Object]
    # @return [Object]
    def fetch(key, ...)
      @data.fetch(key.to_sym, ...)
    end

    # @param keys [Array<Symbol, String>]
    # @return [Object, nil]
    def dig(*keys)
      @data.dig(*keys.map { |k| k.is_a?(String) ? k.to_sym : k })
    end

    # @return [Boolean]
    def key?(key)
      @data.key?(key.to_sym)
    end

    # Fetch existing value or store and return the default.
    #
    # @param key [Symbol, String]
    # @param default [Object]
    # @return [Object]
    def fetch_or_store(key, default = nil)
      sym = key.to_sym
      return @data[sym] if @data.key?(sym)

      @data[sym] = default
    end

    # @param other [Hash]
    # @return [self]
    def merge!(other)
      other.each { |k, v| @data[k.to_sym] = v }
      self
    end

    # @param key [Symbol, String]
    # @return [Object, nil]
    def delete!(key)
      @data.delete(key.to_sym)
    end

    # @return [self]
    def clear!
      @data.clear
      self
    end

    # @yield [key, value]
    def each(&)
      @data.each(&)
    end

    # @yield [key, value]
    # @return [Array]
    def map(&)
      @data.map(&)
    end

    # @return [Hash] a duplicate of the internal data
    def to_h
      @data.dup
    end
    alias to_hash to_h

    # @return [Boolean]
    def empty?
      @data.empty?
    end

    # @return [Integer]
    def size
      @data.size
    end

    # @return [Array<Symbol>]
    def keys
      @data.keys
    end

    # @return [Array]
    def values
      @data.values
    end

    def freeze
      @data.freeze
      super
    end

    def inspect
      "#<#{self.class} #{@data.inspect}>"
    end

    private

    def respond_to_missing?(name, include_private = false)
      writer = name.to_s.end_with?("=")
      key = writer ? name.to_s.chomp("=").to_sym : name.to_sym
      writer || @data.key?(key) || super
    end

    def method_missing(name, *args)
      method_name = name.to_s

      if method_name.end_with?("=")
        key = method_name.chomp("=").to_sym
        @data[key] = args.first
      elsif @data.key?(name)
        @data[name]
      elsif args.empty?
        nil
      else
        super
      end
    end

  end
end

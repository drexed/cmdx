# frozen_string_literal: true

module CMDx
  class Context

    extend Forwardable

    def_delegators :table, :each_pair, :to_h

    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.to_h.transform_keys(&:to_sym)
    end

    def [](key)
      table[key.to_sym]
    end

    def []=(key, value)
      table[key.to_sym] = value
    end

    def fetch(key, ...)
      table.fetch(key.to_sym, ...)
    end

    def merge!(args = {})
      args.to_h.each { |key, value| self[key.to_sym] = value }
      self
    end

    def delete!(key, &)
      table.delete(key.to_sym, &)
    end

    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    def dig(key, *keys)
      table.dig(key.to_sym, *keys)
    end

    def inspect
      "#<#{self.class.name}#{table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    def table
      @_table ||= {}
    end

    def method_missing(method_name, *args, **_kwargs, &)
      fetch(method_name) do
        self[method_name[0..-2]] = args.first if method_name.end_with?("=")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      table.key?(method_name.to_sym) || super
    end

  end
end

# frozen_string_literal: true

module CMDx
  class Context

    extend Forwardable

    def_delegators :table, :each, :map, :to_h

    def initialize(args = {})
      @table =
        if args.respond_to?(:to_hash)
          args.to_hash
        elsif args.respond_to?(:to_h)
          args.to_h
        else
          raise ArgumentError, "must be respond to `to_h` or `to_hash`"
        end.transform_keys(&:to_sym)
    end

    def self.build(context = {})
      if context.is_a?(self) && !context.frozen?
        context
      elsif context.respond_to?(:context)
        build(context.context)
      else
        new(context)
      end
    end

    def [](key)
      table[key.to_sym]
    end

    def store(key, value)
      table[key.to_sym] = value
    end
    alias []= store

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

    def key?(key)
      table.key?(key.to_sym)
    end

    def dig(key, *keys)
      table.dig(key.to_sym, *keys)
    end

    def to_s
      Utils::Format.to_str(to_h)
    end

    private

    def table
      @table ||= {}
    end

    def method_missing(method_name, *args, **_kwargs, &)
      fetch(method_name) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      key?(method_name) || super
    end

  end
end

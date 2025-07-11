# frozen_string_literal: true

module CMDx
  class LazyStruct

    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.to_h.transform_keys { |k| symbolized_key(k) }
    end

    def [](key)
      table[symbolized_key(key)]
    end

    def fetch!(key, ...)
      table.fetch(symbolized_key(key), ...)
    end

    def store!(key, value)
      table[symbolized_key(key)] = value
    end
    alias []= store!

    def merge!(args = {})
      args.to_h.each { |key, value| store!(symbolized_key(key), value) }
      self
    end

    def delete!(key, &)
      table.delete(symbolized_key(key), &)
    end
    alias delete_field! delete!

    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    def dig(key, *keys)
      table.dig(symbolized_key(key), *keys)
    end

    def each_pair(&)
      table.each_pair(&)
    end

    def to_h(&)
      table.to_h(&)
    end

    def inspect
      "#<#{self.class.name}#{table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    def table
      @table ||= {}
    end

    def method_missing(method_name, *args, **_kwargs, &)
      table.fetch(symbolized_key(method_name)) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      table.key?(symbolized_key(method_name)) || super
    end

    def symbolized_key(key)
      key.to_sym
    rescue NoMethodError
      raise TypeError, "#{key} is not a symbol nor a string"
    end

  end
end

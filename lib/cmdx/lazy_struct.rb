# frozen_string_literal: true

module CMDx
  class LazyStruct

    def initialize(args = {})
      unless args.respond_to?(:to_h)
        raise ArgumentError,
              "must be respond to `to_h`"
      end

      @table = args.transform_keys(&:to_sym)
    end

    def [](key)
      @table[key.to_sym]
    end

    def fetch!(key, ...)
      @table.fetch(key.to_sym, ...)
    end

    def store!(key, value)
      @table[key.to_sym] = value
    end
    alias []= store!

    def merge!(args = {})
      args.to_h.each { |key, value| store!(key, value) }
      self
    end

    def delete!(key, &)
      @table.delete(key.to_sym, &)
    end
    alias delete_field! delete!

    def eql?(other)
      other.is_a?(self.class) && (to_h == other.to_h)
    end
    alias == eql?

    def dig(key, *keys)
      begin
        key = key.to_sym
      rescue NoMethodError
        raise TypeError, "#{key} is not a symbol nor a string"
      end

      @table.dig(key, *keys)
    end

    def each_pair(&)
      @table.each_pair(&)
    end

    def to_h(&)
      @table.to_h(&)
    end

    def inspect
      "#<#{self.class}#{@table.map { |key, value| ":#{key}=#{value.inspect}" }.join(' ')}>"
    end
    alias to_s inspect

    private

    def method_missing(method_name, *args, **_kwargs, &)
      @table.fetch(method_name.to_sym) do
        store!(method_name[0..-2], args.first) if method_name.end_with?("=")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @table.key?(method_name.to_sym) || super
    end

  end
end

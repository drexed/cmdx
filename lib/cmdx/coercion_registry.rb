# frozen_string_literal: true

module CMDx
  class CoercionRegistry

    attr_reader :registry

    def initialize(registry = nil)
      @registry = registry || {
        array: Coercions::Array,
        big_decimal: Coercions::BigDecimal,
        boolean: Coercions::Boolean,
        complex: Coercions::Complex,
        date: Coercions::Date,
        datetime: Coercions::DateTime,
        float: Coercions::Float,
        hash: Coercions::Hash,
        integer: Coercions::Integer,
        rational: Coercions::Rational,
        string: Coercions::String,
        time: Coercions::Time
      }
    end

    def dup
      self.class.new(registry.dup)
    end

    def register(name, coercion)
      registry[name.to_sym] = coercion
      self
    end

    def coerce!(type, task, value, options = {})
      raise UnknownCoercionError, "unknown coercion #{type}" unless registry.key?(type)

      Utils::Call.invoke!(task, registry[type], value, options)
    end

  end
end

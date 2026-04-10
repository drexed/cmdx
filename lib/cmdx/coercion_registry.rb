# frozen_string_literal: true

module CMDx
  # Registry of coercion types mapping symbols to coercion classes.
  # Uses copy-on-write for safe inheritance across task classes.
  class CoercionRegistry

    # @rbs BUILT_INS: Hash[Symbol, String]
    BUILT_INS = {
      array: "Coercions::Array",
      big_decimal: "Coercions::BigDecimal",
      boolean: "Coercions::Boolean",
      complex: "Coercions::Complex",
      date: "Coercions::Date",
      date_time: "Coercions::DateTime",
      float: "Coercions::Float",
      hash: "Coercions::Hash",
      integer: "Coercions::Integer",
      rational: "Coercions::Rational",
      string: "Coercions::String",
      symbol: "Coercions::Symbol",
      time: "Coercions::Time"
    }.freeze

    # @rbs @registry: Hash[Symbol, untyped]
    attr_reader :registry

    # @rbs (?Hash[Symbol, untyped]? registry) -> void
    def initialize(registry = nil)
      @registry = registry || {}
    end

    # Returns the coercion class for the given type.
    #
    # @param type [Symbol, Class] the coercion type
    #
    # @return [Class] the coercion class
    # @raise [UnknownCoercionError] when the type is unknown
    #
    # @rbs (untyped type) -> untyped
    def resolve(type)
      return type if type.is_a?(Class) || type.is_a?(Module)

      name = type.to_sym
      registry[name] || resolve_built_in(name)
    end

    # Registers a custom coercion type.
    #
    # @param name [Symbol] the type name
    # @param klass [Class] the coercion class
    #
    # @rbs (Symbol name, untyped klass) -> void
    def register(name, klass)
      registry[name.to_sym] = klass
    end

    # @return [CoercionRegistry] a duplicated registry for child classes
    #
    # @rbs () -> CoercionRegistry
    def for_child
      self.class.new(registry.dup)
    end

    private

    # @rbs (Symbol name) -> untyped
    def resolve_built_in(name)
      const_name = BUILT_INS[name]
      raise UnknownCoercionError, Locale.t("cmdx.coercions.unknown", type: name) unless const_name

      CMDx.const_get(const_name)
    end

  end
end

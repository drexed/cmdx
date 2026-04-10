# frozen_string_literal: true

module CMDx
  # Registry of validator types mapping symbols to validator classes.
  # Uses copy-on-write for safe inheritance across task classes.
  class ValidatorRegistry

    # @rbs BUILT_INS: Hash[Symbol, String]
    BUILT_INS = {
      absence: "Validators::Absence",
      exclusion: "Validators::Exclusion",
      format: "Validators::Format",
      inclusion: "Validators::Inclusion",
      length: "Validators::Length",
      numeric: "Validators::Numeric",
      presence: "Validators::Presence"
    }.freeze

    # @rbs @registry: Hash[Symbol, untyped]
    attr_reader :registry

    # @rbs (?Hash[Symbol, untyped]? registry) -> void
    def initialize(registry = nil)
      @registry = registry || {}
    end

    # Returns the validator class for the given type.
    #
    # @param type [Symbol, Class] the validator type
    #
    # @return [Class] the validator class
    # @raise [UnknownValidatorError] when the type is unknown
    #
    # @rbs (untyped type) -> untyped
    def resolve(type)
      return type if type.is_a?(Class) || type.is_a?(Module)

      name = type.to_sym
      registry[name] || resolve_built_in(name)
    end

    # Registers a custom validator type.
    #
    # @param name [Symbol] the type name
    # @param klass [Class] the validator class
    #
    # @rbs (Symbol name, untyped klass) -> void
    def register(name, klass)
      registry[name.to_sym] = klass
    end

    # @return [ValidatorRegistry] a duplicated registry for child classes
    #
    # @rbs () -> ValidatorRegistry
    def for_child
      self.class.new(registry.dup)
    end

    private

    # @rbs (Symbol name) -> untyped
    def resolve_built_in(name)
      const_name = BUILT_INS[name]
      raise UnknownValidatorError, "unknown validator: #{name}" unless const_name

      CMDx.const_get(const_name)
    end

  end
end

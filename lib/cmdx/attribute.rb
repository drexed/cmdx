# frozen_string_literal: true

module CMDx
  # Defines a single task attribute with its options (type, default, validations, etc.)
  class Attribute

    # @return [Symbol] the attribute name
    attr_reader :name

    # @return [Symbol, nil] the coercion type
    attr_reader :type

    # @return [Boolean] whether the attribute is required
    attr_reader :required

    # @return [Object, nil] default value or callable
    attr_reader :default

    # @return [Symbol, nil] alias name for the accessor
    attr_reader :as

    # @return [Symbol, nil] source method for value resolution
    attr_reader :from

    # @return [Proc, nil] derivation callable
    attr_reader :derive

    # @return [Proc, nil] transformation callable
    attr_reader :transform

    # @return [Hash{Symbol => Hash}] validation rules
    attr_reader :validations

    # @return [Hash] raw options
    attr_reader :options

    # @param name [Symbol] the attribute name
    # @param type [Symbol, nil] the coercion type
    # @param options [Hash] attribute options
    #
    # @rbs (Symbol name, ?Symbol? type, **untyped options) -> void
    def initialize(name, type = nil, **options)
      @name = name.to_sym
      @type = type
      @required = options.fetch(:required, true)
      @default = options[:default]
      @as = options[:as]&.to_sym
      @from = options[:from]&.to_sym
      @derive = options[:derive]
      @transform = options[:transform]
      @validations = extract_validations(options)
      @options = options
    end

    # The name used for the accessor method and attributes hash key.
    #
    # @return [Symbol]
    #
    # @rbs () -> Symbol
    def allocation_name
      as || name
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def required?
      !!required
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def optional?
      !required?
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def typed?
      !type.nil?
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def default?
      !default.nil?
    end
    alias has_default? default?

    # @return [Hash{Symbol => Object}]
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      { name:, type:, required:, default:, as:, from:, validations: }
    end

    private

    # Extracts validation rules from the options hash.
    #
    # @rbs (Hash[Symbol, untyped] options) -> Hash[Symbol, Hash[Symbol, untyped]]
    def extract_validations(options)
      validations = {}
      ValidatorRegistry::BUILT_INS.each_key do |key|
        validations[key] = options[key] if options.key?(key)
      end
      validations[:presence] = true if required? && !validations.key?(:presence)
      validations
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Frozen specification for a single declared attribute.
  # Built from DSL declarations and compiled into a Definition.
  class Attribute

    # Keys consumed by Attribute; everything else goes to validators.
    RESERVED_KEYS = %i[type types as from derive default transform required children].freeze

    # @return [Symbol]
    attr_reader :name

    # @return [Symbol] the accessor name (controlled by +:as+ option)
    attr_reader :reader_name

    # @return [Array<Symbol>] ordered coercion type keys
    attr_reader :type_keys

    # @return [Boolean]
    attr_reader :required

    # @return [Object, nil] default value or callable
    attr_reader :default

    # @return [Symbol, nil] source method/context key override
    attr_reader :from

    # @return [Symbol, Proc, nil] derive callable
    attr_reader :derive

    # @return [Symbol, Proc, nil] transform callable
    attr_reader :transform

    # @return [Array<Hash>] validator entries [{name:, options:}, ...]
    attr_reader :validations

    # @return [Array<Attribute>, nil] child attributes for nested hashes
    attr_reader :children

    # @return [Hash] raw options
    attr_reader :options

    # @param name [Symbol]
    # @param options [Hash]
    # @param children [Array<Attribute>, nil]
    #
    # @rbs (Symbol name, Hash[Symbol, untyped] options, ?Array[Attribute]? children) -> void
    def initialize(name, options = {}, children = nil)
      @name = name.to_sym
      @reader_name = (options[:as] || name).to_sym
      @type_keys = resolve_types(options)
      @required = !!options[:required]
      @default = options[:default]
      @from = options[:from]
      @derive = options[:derive]
      @transform = options[:transform]
      @children = children&.freeze
      @options = options.except(*RESERVED_KEYS).freeze
      @validations = extract_validations(options).freeze
      freeze
    end

    # @return [Boolean]
    # @rbs () -> bool
    def required?
      @required
    end

    # @return [Boolean]
    # @rbs () -> bool
    def optional?
      !@required
    end

    # @return [Boolean]
    # @rbs () -> bool
    def nested?
      !@children.nil? && !@children.empty?
    end

    # @return [Hash]
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      { name: @name, reader_name: @reader_name, type_keys: @type_keys,
        required: @required, validations: @validations, nested: nested? }
    end

    private

    # @rbs (Hash[Symbol, untyped] opts) -> Array[Symbol]
    def resolve_types(opts)
      types = opts[:types] || opts[:type]
      Array(types).compact.map(&:to_sym)
    end

    # @rbs (Hash[Symbol, untyped] opts) -> Array[Hash[Symbol, untyped]]
    def extract_validations(opts)
      known_validators = %i[presence absence format inclusion exclusion length numeric]
      entries = []

      entries << { name: :presence, options: { presence: true } } if @required && !opts.key?(:presence)

      known_validators.each do |vname|
        next unless opts.key?(vname)

        entries << { name: vname, options: { vname => opts[vname] } }
      end

      non_reserved = opts.keys - RESERVED_KEYS - known_validators
      non_reserved.each do |key|
        entries << { name: key, options: { key => opts[key] } }
      end

      entries
    end

  end
end

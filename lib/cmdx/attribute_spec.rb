# frozen_string_literal: true

module CMDx
  # Frozen description of one task input (no runtime +task+ binding).
  class AttributeSpec

    # @return [Symbol]
    attr_reader :name

    # @return [Symbol] reader method
    attr_reader :reader_name

    # @return [Boolean]
    attr_reader :required

    # @return [Array<Symbol>] coercion type keys (first wins)
    attr_reader :type_keys

    # @return [Hash{Symbol => Object}]
    attr_reader :options

    # @return [Array<Hash{Symbol => Object}>] each has +:name+ and optional +:options+, +:if+, +:unless+
    attr_reader :validators

    # @param name [Symbol]
    # @param required [Boolean]
    # @param type_keys [Array<Symbol>]
    # @param reader_name [Symbol, nil]
    # @param options [Hash]
    # @param validators [Array<Hash>]
    # rubocop:disable Metrics/ParameterLists
    def initialize(name:, required:, type_keys:, reader_name: nil, options: {}, validators: [])
      @name = name.to_sym
      @required = required
      @type_keys = type_keys.map(&:to_sym).freeze
      @reader_name = (reader_name || @name).to_sym
      @options = options.freeze
      @validators = validators.freeze
      freeze
    end
    # rubocop:enable Metrics/ParameterLists

  end
end

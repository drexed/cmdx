# frozen_string_literal: true

module CMDx
  # Parameter inspection utility for generating human-readable parameter descriptions.
  #
  # The ParameterInspector module provides functionality to convert parameter
  # hash representations into formatted, human-readable strings. It handles
  # nested parameter structures with proper indentation and ordering.
  #
  # @example Basic parameter inspection
  #   parameter_hash = {
  #     name: :user_id,
  #     type: :integer,
  #     source: :context,
  #     required: true,
  #     options: { numeric: { min: 1 } },
  #     children: []
  #   }
  #   ParameterInspector.call(parameter_hash)
  #   # => "Parameter: name=user_id type=integer source=context required=true options={numeric: {min: 1}}"
  #
  # @example Nested parameter inspection
  #   nested_parameter = {
  #     name: :address,
  #     type: :virtual,
  #     source: :context,
  #     required: true,
  #     options: {},
  #     children: [
  #       { name: :street, type: :string, source: :address, required: true, options: {}, children: [] }
  #     ]
  #   }
  #   ParameterInspector.call(nested_parameter)
  #   # => "Parameter: name=address type=virtual source=context required=true options={}
  #   #       ↳ Parameter: name=street type=string source=address required=true options={}"
  #
  # @see CMDx::Parameter Parameter hash serialization via to_h
  # @see CMDx::ParameterSerializer Parameter-to-hash conversion
  module ParameterInspector

    # Ordered keys for consistent parameter inspection output.
    #
    # Defines the order in which parameter attributes are displayed
    # in the inspection string, with children handled specially.
    ORDERED_KEYS = %i[
      name type source required options children
    ].freeze

    module_function

    # Converts a parameter hash to a human-readable string representation.
    #
    # Formats parameter data into a structured string with proper ordering
    # and indentation for nested parameters. Child parameters are displayed
    # with increased indentation and arrow prefixes.
    #
    # @param parameter [Hash] The parameter hash to inspect
    # @param depth [Integer] The current nesting depth for indentation (default: 1)
    # @return [String] Formatted parameter description
    #
    # @example Single parameter inspection
    #   ParameterInspector.call(param_hash)
    #   # => "Parameter: name=user_id type=integer source=context required=true"
    #
    # @example Nested parameter inspection with custom depth
    #   ParameterInspector.call(param_hash, 2)
    #   # => "Parameter: name=address type=virtual source=context required=true
    #   #         ↳ Parameter: name=street type=string source=address required=true"
    #
    # @example Parameter with options
    #   ParameterInspector.call(param_with_validation)
    #   # => "Parameter: name=email type=string source=context required=true options={format: {with: /@/}}"
    def call(parameter, depth = 1)
      ORDERED_KEYS.filter_map do |key|
        value = parameter[key]
        next "#{key}=#{value}" unless key == :children

        spaces = " " * (depth * 2)
        value.map { |h| "\n#{spaces}↳ #{call(h, depth + 1)}" }.join
      end.unshift("Parameter:").join(" ")
    end

  end
end

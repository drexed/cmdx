# frozen_string_literal: true

module CMDx
  # Provides formatted inspection and display functionality for parameter objects.
  #
  # This module formats parameter information into human-readable string representations,
  # including nested parameter structures with proper indentation. It processes parameter
  # hashes in a consistent order and handles child parameter relationships for complex
  # parameter hierarchies.
  module ParameterInspector

    ORDERED_KEYS = %i[
      name type source required options children
    ].freeze

    module_function

    # Formats a parameter hash into a human-readable inspection string.
    #
    # Creates a formatted string representation of parameter information,
    # displaying attributes in a consistent order with proper indentation
    # for nested child parameters. The method recursively processes child
    # parameters with increased indentation depth for visual hierarchy.
    #
    # @param parameter [Hash] the parameter hash to format
    # @option parameter [Symbol, String] :name the parameter name
    # @option parameter [Symbol, Array<Symbol>] :type the parameter type(s)
    # @option parameter [Symbol] :source the parameter source context
    # @option parameter [Boolean] :required whether the parameter is required
    # @option parameter [Hash] :options additional parameter configuration options
    # @option parameter [Array<Hash>] :children nested child parameter definitions
    # @param depth [Integer] the indentation depth for nested parameters (defaults to 1)
    #
    # @return [String] formatted multi-line string representation of the parameter
    #
    # @example Format a simple parameter
    #   parameter = { name: :user_id, type: :integer, required: true }
    #   ParameterInspector.call(parameter)
    #   #=> "Parameter: name=user_id type=integer required=true"
    #
    # @example Format a parameter with children
    #   parameter = {
    #     name: :payment,
    #     type: :hash,
    #     required: true,
    #     children: [
    #       { name: :amount, type: :big_decimal, required: true },
    #       { name: :currency, type: :string, required: true }
    #     ]
    #   }
    #   ParameterInspector.call(parameter)
    #   #=> "Parameter: name=payment type=hash required=true
    #   #       ↳ Parameter: name=amount type=big_decimal required=true
    #   #       ↳ Parameter: name=currency type=string required=true"
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

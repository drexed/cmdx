# frozen_string_literal: true

module CMDx
  # Parameter inspection and formatting utilities for readable parameter representation.
  #
  # This module provides functionality to format parameter metadata into human-readable
  # strings for debugging, logging, and introspection purposes. It handles nested
  # parameter structures with proper indentation and displays essential parameter
  # information in a structured format.
  module ParameterInspector

    ORDERED_KEYS = %i[
      name type source required options children
    ].freeze

    module_function

    # Formats a parameter hash into a human-readable string representation.
    #
    # This method converts parameter metadata into a structured string format
    # that displays key parameter information in a consistent order. For parameters
    # with nested children, it recursively formats child parameters with proper
    # indentation to show the hierarchical structure.
    #
    # @param parameter [Hash] the parameter hash to format
    # @param depth [Integer] the current nesting depth for indentation (default: 1)
    #
    # @return [String] a formatted string representation of the parameter
    #
    # @example Format a parameter with nested children
    #   param = {
    #     name: :user, type: :hash, source: :context, required: false, options: {},
    #     children: [
    #       { name: :name, type: :string, source: :user, required: true, options: {}, children: [] },
    #       { name: :age, type: :integer, source: :user, required: false, options: {}, children: [] }
    #     ]
    #   }
    #   ParameterInspector.call(param)
    #   # => "Parameter: name=user type=hash source=context required=false options={}
    #   #      ↳ Parameter: name=name type=string source=user required=true options={}
    #   #      ↳ Parameter: name=age type=integer source=user required=false options={}"
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

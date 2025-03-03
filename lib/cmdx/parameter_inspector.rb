# frozen_string_literal: true

module CMDx
  module ParameterInspector

    ORDERED_KEYS = %i[
      name type source required options children
    ].freeze

    module_function

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

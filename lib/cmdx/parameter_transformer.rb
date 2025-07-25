# frozen_string_literal: true

module CMDx
  module ParameterTransformer

    module_function

    def to_h(parameter)
      {
        source: parameter.source,
        name: parameter.name,
        signature: parameter.signature,
        required: parameter.required?,
        type: parameter.type,
        options: parameter.options,
        children: parameter.children.map(&:to_h)
      }
    end

    def to_s(parameter, depth = 1)
      parameter.keys.filter_map do |key|
        value = parameter[key]

        if key == :children
          spaces = " " * (depth * 2)
          value.map { |child| "\n#{spaces}↳ #{to_s(child, depth + 1)}" }.join
        else
          "#{key}=#{value}"
        end
      end.unshift("Parameter:").join(" ")
    end

  end
end

# frozen_string_literal: true

module CMDx
  module ParameterSerializer

    module_function

    def call(parameter)
      {
        source: parameter.method_source,
        name: parameter.method_name,
        type: parameter.type,
        required: parameter.required?,
        options: parameter.options,
        children: parameter.children.map(&:to_h)
      }
    end

  end
end

# frozen_string_literal: true

module CMDx
  module ParametersInspector

    module_function

    def call(parameters)
      parameters.map(&:to_s).join("\n")
    end

  end
end

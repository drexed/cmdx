# frozen_string_literal: true

module CMDx
  module ParametersSerializer

    module_function

    def call(parameters)
      parameters.registry.map(&:to_h)
    end

  end
end

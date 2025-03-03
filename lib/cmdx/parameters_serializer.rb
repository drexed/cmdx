# frozen_string_literal: true

module CMDx
  module ParametersSerializer

    module_function

    def call(parameters)
      parameters.map(&:to_h)
    end

  end
end

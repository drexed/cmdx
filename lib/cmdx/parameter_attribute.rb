# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :parameter, :value

    def initialize(parameter)
      @parameter = parameter
    end

    def self.call(parameter)
      new(parameter).call
    end

    def call
      generate_value
      coerce_value
      validate_value
      define_value
    end

    private

    def generate_value
    end

    def coerce_value
    end

    def validate_value
    end

    def define_value
    end

  end
end

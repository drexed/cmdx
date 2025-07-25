# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize
      @registry = []
    end

    def register(parameter)
      @registry << parameter
    end

    def define_attributes!
      registry.each(&:define_attributes!)
    end

    def validate_attributes!
      registry.each(&:validate_attributes!)
    end

    def to_h
      registry.map(&:to_h)
    end

    def to_s
      registry.map(&:to_s).join("\n")
    end

  end
end

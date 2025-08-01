# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize(registry = [])
      @registry = registry
    end

    def dup
      self.class.new(registry.dup)
    end

    def register(parameters)
      @registry.concat(Array(parameters))
      self
    end

    def define_and_verify_attribute!(task)
      registry.each_with_object(Errors.new) do |parameter, errors|
        parameter.task = task
        parameter.define_and_verify_attribute!

        recursively_attach_errors_for(parameter, errors)
      end
    end

    private

    def recursively_attach_errors_for(parameter, errors)
      errors.add(parameter.signature, parameter.attribute.errors)
      parameter.children.each { |param| recursively_attach_errors_for(param, errors) }
    end

  end
end

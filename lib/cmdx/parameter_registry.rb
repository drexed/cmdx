# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    # TODO: allow inheriting of parameters??
    attr_reader :registry

    def initialize
      @registry = []
    end

    def register(parameters)
      @registry.concat(Array(parameters))
      self
    end

    def define_and_verify_attribute!(task)
      registry.each_with_object(Errors.new) do |parameter, errors|
        parameter.task = task
        parameter.define_and_verify_attribute!

        recursively_add_attribute_errors_for(parameter, errors)
      end
    end

    private

    def recursively_add_attribute_errors_for(parameter, errors)
      errors.add(parameter.signature, parameter.attribute.errors)
      parameter.children.each { |param| recursively_add_attribute_errors_for(param, errors) }
    end

  end
end

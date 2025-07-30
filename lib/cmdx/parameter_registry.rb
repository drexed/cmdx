# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize
      @registry = []
    end

    class << self

      def define_and_verify_attributes_for(task)
        task.class.settings[:parameters].registry.each_with_object(Errors.new) do |parameter, errors|
          parameter.task = task
          parameter.define_and_verify_attribute!

          deep_flat_map_errors_for(parameter, errors)
        end
      end

      private

      def deep_flat_map_errors_for(parameter, errors)
        errors.add(parameter.signature, parameter.attribute.errors)
        parameter.children.each { |param| deep_flat_map_errors_for(param, errors) }
      end

    end

    def register(parameters)
      @registry.concat(Array(parameters))
      self
    end

  end
end

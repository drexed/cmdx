# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize
      @registry = []
    end

    class << self

      def define_attributes_for(task)
        task.class.settings[:parameters].registry.each do |parameter|
          parameter.schema.task = task
          parameter.schema.define_attribute!
        end
      end

      def validate_attributes_for(task)
        task.class.settings[:parameters].registry.each do |parameter|
          parameter.schema.task = task
          parameter.schema.validate_attribute!
        end
      end

    end

    def register(parameters)
      @registry.concat(Array(parameters))
    end

  end
end

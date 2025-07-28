# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize
      @registry = []
    end

    class << self

      def define_and_certify_attributes_for(task)
        task.class.settings[:parameters].registry.each do |parameter|
          parameter.schema.task = task
          parameter.schema.define_and_certify_attribute!
        end
      end

    end

    def register(parameters)
      @registry.concat(Array(parameters))
    end

  end
end

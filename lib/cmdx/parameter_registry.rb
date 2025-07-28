# frozen_string_literal: true

module CMDx
  class ParameterRegistry

    attr_reader :registry

    def initialize
      @registry = []
    end

    class << self

      def define_and_verify_attributes_for(task)
        task.class.settings[:parameters].registry.each do |parameter|
          parameter.task = task
          parameter.define_and_verify_attribute!
        end
      end

    end

    def register(parameters)
      @registry.concat(Array(parameters))
    end

  end
end

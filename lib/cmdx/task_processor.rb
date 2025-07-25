# frozen_string_literal: true

module CMDx
  class TaskProcessor

    attr_reader :task

    def initialize(task)
      @task = task
    end

    class << self

      def call(task)
        new(task).call
      end

      def call!(task)
        new(task).call!
      end

    end

    def call
      ParameterRegistry.define_attributes_for(task)
      # ParameterRegistry.validate_attributes_for(task)

      task.call
    end

    def call!
      # Do nothing
    end

  end
end

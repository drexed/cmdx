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
      ParameterRegistry.define_and_certify_attributes_for(task)

      task.call
    end

    def call!
      # Do nothing
    end

  end
end

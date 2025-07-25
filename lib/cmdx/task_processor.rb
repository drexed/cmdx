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
      define_parameter_attributes
      validate_parameter_attributes

      task.call
    end

    def call!
      # Do nothing
    end

    private

    def define_parameter_attributes
      task.class.settings[:parameters].define_attributes!
    end

    def validate_parameter_attributes
      task.class.settings[:parameters].validate_attributes!
    end

  end
end

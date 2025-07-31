# frozen_string_literal: true

module CMDx
  class Processor

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
      before_execution!
      process_parameters!

      task.call
    end

    def call!
      # Do nothing
    end

    private

    def before_execution!
      # task.class.settings[:callbacks].invoke!(:before_execution, task)
      # task.result.executing!
      # task.class.settings[:callbacks].invoke!(:on_executing, task)
    end

    def process_parameters!
      task.class.settings[:callbacks].invoke!(:before_validation, task)
      errors = task.class.settings[:parameters].define_and_verify_attributes_for(task)
      task.result.fail!(reason: errors.to_s, messages: errors.to_h) unless errors.empty?
      task.class.settings[:callbacks].invoke!(:after_validation, task)
    end

  end
end

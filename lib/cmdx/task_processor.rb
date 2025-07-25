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
      task.class.settings[:parameters].call

      task.call
    end

    def call!
      # Do nothing
    end

  end
end

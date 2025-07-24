# frozen_string_literal: true

module CMDx
  class TaskProcessor

    extend Forwardable

    def_delegators :klass, :settings

    attr_reader :task, :klass

    def initialize(task)
      @task  = task
      @klass = task.class
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
      settings[:parameters].tap do |parameters|
        parameters.call
        # task.result.fail!
      end
    end

    def call!
      # Do nothing
    end

  end
end

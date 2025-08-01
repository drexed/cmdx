# frozen_string_literal: true

module CMDx
  class Processor

    attr_reader :task

    def initialize(task)
      @task = task
    end

    class << self

      def execute(task)
        new(task).execute
      end

      def execute!(task)
        new(task).execute!
      end

    end

    def execute
      # NOTE: No need to clear the Chain since exception is not being re-raised

      task.class.settings[:middlewares].call!(task) do
        pre_execution!
        execution!
      rescue UndefinedMethodError => e
        raise(e)
      rescue Fault => e
        task.result.throw!(e.result, original_exception: e) if halt_execution?(e)
      rescue StandardError => e
        task.result.fail!(reason: "[#{e.class}] #{e.message}", original_exception: e)
      ensure
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    def execute!
      task.class.settings[:middlewares].call!(task) do
        before_execution!
        execution!
      rescue UndefinedMethodError => e
        raise_exception!(e)
      rescue Fault => e
        task.result.executed!

        raise_exception!(e) if halt_execution?(e)

        post_execution!
      else
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    protected

    def halt_execution?(exception)
      Array(task.class.settings[:task_halts]).include?(exception.result.status)
    end

    def raise_exception!(exception)
      Chain.clear
      raise(exception)
    end

    private

    def pre_execution!
      task.class.settings[:callbacks].invoke!(:before_validation, task)

      errors = task.class.settings[:parameters].define_and_verify_attribute!(task)
      task.result.fail!(reason: errors.to_s, messages: errors.to_h) unless errors.empty?
    end

    def execution!
      task.class.settings[:callbacks].invoke!(:before_execution, task)

      task.result.executing!
      task.command
    end

    def post_execution!
      task.class.settings[:callbacks].invoke!(:"on_#{task.result.state}", task)
      task.class.settings[:callbacks].invoke!(:on_executed, task) if task.result.executed?

      task.class.settings[:callbacks].invoke!(:"on_#{task.result.status}", task)
      task.class.settings[:callbacks].invoke!(:on_good, task) if task.result.good?
      task.class.settings[:callbacks].invoke!(:on_bad, task) if task.result.bad?
    end

    def finalize_execution!
      Immutator.freeze!(task)
      # TODO: ResultLogger.call(task.result) # Do we use emitters?
    end

  end
end

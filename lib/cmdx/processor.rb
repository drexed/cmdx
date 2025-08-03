# frozen_string_literal: true

module CMDx
  class Processor

    attr_reader :task

    def initialize(task)
      @task = task
    end

    class << self

      def execute(task, halt: false)
        instance = new(task)
        halt ? instance.execute! : instance.execute
      end

    end

    def execute
      task.class.settings[:middlewares].call!(task) do
        pre_execution!
        execution!
      rescue UndefinedMethodError => e
        raise(e) # No need to clear the Chain since exception is not being re-raised
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

      task.class.settings[:attributes].define_and_verify(task)
      return if task.errors.empty?

      task.result.fail!(reason: task.errors.to_s, messages: task.errors.to_h)
    end

    def execution!
      task.class.settings[:callbacks].invoke!(:before_execution, task)

      task.result.executing!
      task.task
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
      # TODO: ResultLogger.call(task.result) # Do we use emitters? Do we move it a middleware?
    end

  end
end

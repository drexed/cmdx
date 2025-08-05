# frozen_string_literal: true

module CMDx
  class Processor

    attr_reader :task

    def initialize(task)
      @task = task
    end

    def self.execute(task, raise: false)
      instance = new(task)
      raise ? instance.execute! : instance.execute
    end

    def execute
      task.class.settings[:middlewares].call!(task) do
        pre_execution!
        execution!
      rescue UndefinedMethodError => e
        raise(e) # No need to clear the Chain since exception is not being re-raised
      rescue Fault => e
        task.result.throw!(e.result, cause: e) if halt_execution?(e)
      rescue StandardError => e
        task.result.fail!("[#{e.class}] #{e.message}", cause: e)
      ensure
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    def execute!
      task.class.settings[:middlewares].call!(task) do
        pre_execution!
        execution!
      rescue UndefinedMethodError => e
        raise_exception!(e)
      rescue Fault => e
        task.result.fail!(e.result.reason, cause: e)
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
      Array(task.class.settings[:task_breakpoints]).include?(exception.result.status)
    end

    def raise_exception!(exception)
      Chain.clear
      raise(exception)
    end

    private

    def pre_execution!
      task.class.settings[:callbacks].invoke(:before_validation, task)

      task.class.settings[:attributes].define_and_verify(task)
      return if task.errors.empty?

      task.result.fail!(task.errors.to_s, messages: task.errors.to_h)
    end

    def execution!
      task.class.settings[:callbacks].invoke(:before_execution, task)

      task.result.executing!
      task.task
    end

    def post_execution!
      task.class.settings[:callbacks].invoke(:"on_#{task.result.state}", task)
      task.class.settings[:callbacks].invoke(:on_executed, task) if task.result.executed?

      task.class.settings[:callbacks].invoke(:"on_#{task.result.status}", task)
      task.class.settings[:callbacks].invoke(:on_good, task) if task.result.good?
      task.class.settings[:callbacks].invoke(:on_bad, task) if task.result.bad?
    end

    def finalize_execution!
      Freezer.immute(task)

      task.logger.tap do |logger|
        logger.with_level(:info) do
          logger.info { task.result.to_h }
        end
      end
    end

  end
end

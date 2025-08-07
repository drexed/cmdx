# frozen_string_literal: true

module CMDx
  class Worker

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
        raise_exception(e)
      rescue Fault => e
        task.result.fail!(e.result.reason, cause: e)
        halt_execution?(e) ? raise_exception(e) : post_execution!
      rescue StandardError => e
        task.result.fail!("[#{e.class}] #{e.message}", cause: e)
        raise_exception(e)
      else
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    protected

    def halt_execution?(exception)
      breakpoints = task.class.settings[:breakpoints] || task.class.settings[:task_breakpoints]
      breakpoints = Array(breakpoints).map(&:to_s).uniq

      breakpoints.include?(exception.result.status)
    end

    def raise_exception(exception)
      Chain.clear
      raise(exception)
    end

    def invoke_callbacks(type)
      task.class.settings[:callbacks].invoke(type, task)
    end

    private

    def pre_execution!
      invoke_callbacks(:before_validation)

      task.class.settings[:attributes].define_and_verify(task)
      return if task.errors.empty?

      task.result.fail!(task.errors.to_s, messages: task.errors.to_h)
    end

    def execution!
      invoke_callbacks(:before_execution)

      task.result.executing!
      task.work
    end

    def post_execution!
      invoke_callbacks(:"on_#{task.result.state}")
      invoke_callbacks(:on_executed) if task.result.executed?

      invoke_callbacks(:"on_#{task.result.status}")
      invoke_callbacks(:on_good) if task.result.good?
      invoke_callbacks(:on_bad) if task.result.bad?
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

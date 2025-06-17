# frozen_string_literal: true

module CMDx
  class Task

    HOOKS = [
      :before_validation,
      :after_validation,
      :before_execution,
      :after_execution,
      :on_executed,
      :on_good,
      :on_bad,
      *Result::STATUSES.map { |s| :"on_#{s}" },
      *Result::STATES.map { |s| :"on_#{s}" }
    ].freeze

    __cmdx_attr_setting :task_settings, default: -> { CMDx.configuration.to_h.merge(tags: []) }
    __cmdx_attr_setting :cmd_parameters, default: -> { Parameters.new }
    __cmdx_attr_setting :cmd_hooks, default: {}

    __cmdx_attr_delegator :task_setting, :task_setting?, to: :class
    __cmdx_attr_delegator :skip!, :fail!, :throw!, to: :result

    attr_reader :id, :errors, :context, :result, :run
    alias ctx context
    alias res result

    private_class_method :new

    def initialize(context = {})
      @id      = SecureRandom.uuid
      @errors  = Errors.new
      @context = Context.build(context)
      @run = @context.run || begin
        run = Run.new(@context.delete!(:run).to_h)
        @context.instance_variable_set(:@run, run)
      end
      @run.results << @result = Result.new(self)
    end

    class << self

      HOOKS.each do |hook|
        define_method(hook) do |*callables, **options, &block|
          callables << block if block_given?
          (cmd_hooks[hook] ||= []).push([callables, options]).uniq!
        end
      end

      def task_setting(key)
        __cmdx_yield(task_settings[key])
      end

      def task_setting?(key)
        task_settings.key?(key)
      end

      def task_settings!(**options)
        task_settings.merge!(options)
      end

      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.concat(parameters)
      end

      def required(*attributes, **options, &)
        parameters = Parameter.required(*attributes, **options.merge(klass: self), &)
        cmd_parameters.concat(parameters)
      end

      def call(...)
        instance = send(:new, ...)
        instance.send(:execute_call)
        instance.result
      end

      def call!(...)
        instance = send(:new, ...)
        instance.send(:execute_call!)
        instance.result
      end

    end

    # TODO: rename call to perform???
    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    private

    def logger
      Logger.call(self)
    end

    def before_call
      TaskHook.call(self, :before_execution)

      result.executing!
      TaskHook.call(self, :on_executing)

      TaskHook.call(self, :before_validation)
      ParameterValidator.call(self)
      TaskHook.call(self, :after_validation)
    end

    def after_call
      TaskHook.call(self, :"on_#{result.state}")
      TaskHook.call(self, :on_executed) if result.executed?

      TaskHook.call(self, :"on_#{result.status}")
      TaskHook.call(self, :on_good) if result.good?
      TaskHook.call(self, :on_bad) if result.bad?

      TaskHook.call(self, :after_execution)
    end

    def terminate_call
      Immutator.call(self)
      ResultLogger.call(result)
    end

    def execute_call
      result.runtime do
        before_call
        call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        throw!(e.result, original_exception: e) if Array(task_setting(:task_halt)).include?(e.result.status)
      rescue StandardError => e
        fail!(reason: "[#{e.class}] #{e.message}", original_exception: e)
      ensure
        result.executed!
        after_call
      end

      terminate_call
    end

    def execute_call!
      result.runtime do
        before_call
        call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        result.executed!
        raise(e) if Array(task_setting(:task_halt)).include?(e.result.status)

        after_call # HACK: treat as NO-OP
      else
        result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

  end
end

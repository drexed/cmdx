# frozen_string_literal: true

module CMDx
  class Task

    cmdx_attr_setting :task_settings,
                      default: -> { CMDx.configuration.to_h.slice(:logger, :task_halt, :workflow_halt).merge(tags: []) }
    cmdx_attr_setting :cmd_middlewares,
                      default: -> { MiddlewareRegistry.new(CMDx.configuration.middlewares) }
    cmdx_attr_setting :cmd_callbacks,
                      default: -> { CallbackRegistry.new(CMDx.configuration.callbacks) }
    cmdx_attr_setting :cmd_parameters,
                      default: -> { ParameterRegistry.new }

    cmdx_attr_delegator :cmd_middlewares, :cmd_callbacks, :cmd_parameters, :task_setting, :task_setting?,
                        to: :class
    cmdx_attr_delegator :skip!, :fail!, :throw!,
                        to: :result

    # @return [Context] parameter context for this task execution
    attr_reader :context

    # @return [Errors] collection of validation and execution errors
    attr_reader :errors

    # @return [String] unique identifier for this task instance
    attr_reader :id

    # @return [Result] execution result tracking state and status
    attr_reader :result

    # @return [Chain] execution chain containing this task and related executions
    attr_reader :chain

    # @return [Context] alias for context
    alias ctx context

    # @return [Result] alias for result
    alias res result

    def initialize(context = {})
      context  = context.context if context.respond_to?(:context)

      @context = Context.build(context)
      @errors  = Errors.new
      @id      = CMDx::Correlator.generate
      @result  = Result.new(self)
      @chain   = Chain.build(@result)
    end

    class << self

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          cmd_callbacks.register(callback, *callables, **options, &block)
        end
      end

      def task_setting(key)
        cmdx_yield(task_settings[key])
      end

      def task_setting?(key)
        task_settings.key?(key)
      end

      def task_settings!(**options)
        task_settings.merge!(options)
      end

      def use(type, object, ...)
        case type
        when :middleware
          cmd_middlewares.register(object, ...)
        when :callback
          cmd_callbacks.register(type, object, ...)
        when :validator
          cmd_validators.register(type, object, ...)
        when :coercion
          cmd_coercions.register(type, object, ...)
        end
      end

      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      def required(*attributes, **options, &)
        parameters = Parameter.required(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      def call(...)
        instance = new(...)
        instance.perform
        instance.result
      end

      def call!(...)
        instance = new(...)
        instance.perform!
        instance.result
      end

    end

    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    def perform
      return execute_call if cmd_middlewares.registry.empty?

      cmd_middlewares.call(self) { |task| task.send(:execute_call) }
    end

    def perform!
      return execute_call! if cmd_middlewares.registry.empty?

      cmd_middlewares.call(self) { |task| task.send(:execute_call!) }
    end

    private

    def logger
      Logger.call(self)
    end

    def before_call
      cmd_callbacks.call(self, :before_execution)

      result.executing!
      cmd_callbacks.call(self, :on_executing)

      cmd_callbacks.call(self, :before_validation)
      ParameterValidator.call(self)
      cmd_callbacks.call(self, :after_validation)
    end

    def after_call
      cmd_callbacks.call(self, :"on_#{result.state}")
      cmd_callbacks.call(self, :on_executed) if result.executed?

      cmd_callbacks.call(self, :"on_#{result.status}")
      cmd_callbacks.call(self, :on_good) if result.good?
      cmd_callbacks.call(self, :on_bad) if result.bad?

      cmd_callbacks.call(self, :after_execution)
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
        Chain.clear
        raise(e)
      rescue Fault => e
        result.executed!

        if Array(task_setting(:task_halt)).include?(e.result.status)
          Chain.clear
          raise(e)
        end

        after_call # HACK: treat as NO-OP
      else
        result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

  end
end

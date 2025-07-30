# frozen_string_literal: true

module CMDx
  class Task

    extend Forwardable

    def_delegators :result, :skip!, :fail!, :throw!

    attr_reader :context, :result

    def initialize(context = {})
      context = context.context if context.respond_to?(:context)

      @context = Context.new(context)
      @result = Result.new(self)
    end

    class << self

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
      end

      def settings
        @settings ||=
          if superclass.respond_to?(:configuration)
            superclass.configuration
          else
            CMDx.configuration.to_h
          end.transform_values(&:dup).merge!(
            parameters: ParameterRegistry.new,
            tags: []
          )
      end

      def settings!(**options)
        settings.merge!(options)
      end

      def register(type, object, ...)
        case type
        when /middleware/ then settings[:middlewares].register(object, ...)
        when /callback/ then settings[:callbacks].register(object, ...)
        when /coercion/ then settings[:coercions].register(object, ...)
        when /validator/ then settings[:validators].register(object, ...)
        end
      end

      def parameter(name, ...)
        param = Parameter.parameter(name, ...)
        settings[:parameters].register(param)
      end

      def parameters(...)
        params = Parameter.parameters(...)
        settings[:parameters].register(params)
      end

      def optional(...)
        params = Parameter.optional(...)
        settings[:parameters].register(params)
      end

      def required(...)
        params = Parameter.required(...)
        settings[:parameters].register(params)
      end

      def call(...)
        task = new(...)
        task.call_with_middlewares
        task.result
      end

      def call!(...)
        task = new(...)
        task.call_with_middlewares!
        task.result
      end

    end

    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    def call_with_middlewares
      TaskProcessor.call(self)
      # self.class.settings[:middlewares].call(self) { |task| TaskProcessor.call(task) }
    end

    def call_with_middlewares!
      self.class.settings[:middlewares].call(self) { |task| TaskProcessor.call!(task) }
    end

    def logger
      Logger.call(self)
    end

  end
end

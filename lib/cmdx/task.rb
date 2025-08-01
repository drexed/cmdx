# frozen_string_literal: true

module CMDx
  class Task

    extend Forwardable

    def_delegators :result, :skip!, :fail!, :throw!

    attr_reader :attributes, :id, :context, :result, :chain
    alias ctx context
    alias res result

    def initialize(context = {})
      Utils::Deprecate.invoke!(self)

      @attributes = {}

      @id = Utils::Id.generate!
      @context = Context.build!(context)
      @result = Result.new(self)
      @chain = Chain.build!(@result)
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
            deprecate: false,
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
      alias param parameter

      def parameters(...)
        params = Parameter.parameters(...)
        settings[:parameters].register(params)
      end
      alias params parameters

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
        Processor.call(task)
        task.result
      end

      def call!(...)
        task = new(...)
        Processor.call!(task)
        task.result
      end

    end

    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end

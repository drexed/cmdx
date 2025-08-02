# frozen_string_literal: true

module CMDx
  class Task

    extend Forwardable

    attr_reader :attributes, :id, :context, :result, :chain
    alias ctx context
    alias res result

    def_delegators :result, :skip!, :fail!, :throw!

    def initialize(context = {})
      Utils::Deprecate.invoke!(self)

      @attributes = {} # TODO: change this to hold values and errors

      @id      = Utils::Id.generate!
      @context = Context.build!(context)
      @result  = Result.new(self)
      @chain   = Chain.build!(@result)
    end

    class << self

      def settings(**options)
        @settings ||=
          if superclass.respond_to?(:configuration)
            superclass.configuration
          else
            CMDx.configuration.to_h
          end.transform_values(&:dup).merge!(
            parameters: ParameterRegistry.new,
            deprecate: false,
            tags: [],
            **options
          )
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

      def execute(...)
        task = new(...)
        task.execute(halt: false)
        task.result
      end

      def execute!(...)
        task = new(...)
        task.execute(halt: true)
        task.result
      end

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
      end

    end

    def execute(halt: false)
      Processor.execute(self, halt:)
    end

    def command
      raise UndefinedMethodError, "undefined method #{self.class.name}#command"
    end

  end
end

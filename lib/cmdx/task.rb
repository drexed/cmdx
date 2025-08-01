# frozen_string_literal: true

module CMDx
  class Task

    CMDX_TASK_METHODS = %i[
      attributes id context result chain
      execute execute! skip! fail! throw!
    ].freeze
    private_constant :CMDX_TASK_METHODS

    extend Forwardable

    attr_reader :attributes, :processor, :id, :context, :result, :chain
    alias ctx context
    alias res result

    def_delegators :processor, :execute, :execute!
    def_delegators :result, :skip!, :fail!, :throw!

    def initialize(context = {})
      Utils::Deprecate.invoke!(self)

      @attributes = {}
      @processor  = Processor.new(self)

      @id      = Utils::Id.generate!
      @context = Context.build!(context)
      @result  = Result.new(self)
      @chain   = Chain.build!(@result)
    end

    class << self

      def method_added(method_name)
        if CMDX_TASK_METHODS.include?(method_name)
          # Protect the few methods that are used internally by CMDx
          raise "#{name}##{method_name} cannot be redefined"
        end

        super
      end

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
        task.execute
        task.result
      end

      def execute!(...)
        task = new(...)
        task.execute!
        task.result
      end

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
      end

    end

    def command
      raise UndefinedMethodError, "undefined method #{self.class.name}#command"
    end

  end
end

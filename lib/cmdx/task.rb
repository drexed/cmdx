# frozen_string_literal: true

module CMDx
  class Task

    extend Forwardable

    attr_reader :attributes, :errors, :id, :context, :result, :chain
    alias ctx context
    alias res result

    def_delegators :result, :skip!, :fail!, :throw!

    def initialize(context = {})
      Deprecator.condemn(self)

      @attributes = {}
      @errors = Errors.new

      @id = Identifier.generate
      @context = Context.build(context)
      @result = Result.new(self)
      @chain = Chain.build(@result)
    end

    class << self

      def settings(**options)
        @settings ||=
          if superclass.respond_to?(:configuration)
            superclass.configuration
          else
            CMDx.configuration.to_h
          end.transform_values(&:dup).merge!(
            attributes: AttributeRegistry.new,
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

      def attribute(name, ...)
        attr = Attribute.define(name, ...)
        settings[:attributes].register(attr)
      end

      def attributes(...)
        attrs = Attribute.defines(...)
        settings[:attributes].register(attrs)
      end

      def optional(...)
        attrs = Attribute.optional(...)
        settings[:attributes].register(attrs)
      end

      def required(...)
        attrs = Attribute.required(...)
        settings[:attributes].register(attrs)
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

    def task
      raise UndefinedMethodError, "undefined method #{self.class.name}#task"
    end

  end
end

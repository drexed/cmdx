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
        when :attribute then settings[:attributes].register(object, ...)
        when :callback then settings[:callbacks].register(object, ...)
        when :coercion then settings[:coercions].register(object, ...)
        when :middleware then settings[:middlewares].register(object, ...)
        when :validator then settings[:validators].register(object, ...)
        else raise "unknown register type #{type.inspect}"
        end
      end

      def attribute(name, ...)
        register(:attribute, Attribute.define(name, ...))
      end

      def attributes(...)
        register(:attribute, Attribute.defines(...))
      end

      def optional(...)
        register(:attribute, Attribute.optional(...))
      end

      def required(...)
        register(:attribute, Attribute.required(...))
      end

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
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

    end

    def execute(halt: false)
      Processor.execute(self, halt:)
    end

    def task
      raise UndefinedMethodError, "undefined method #{self.class.name}#task"
    end

    def logger
      self.class.settings[:logger]
    end

    def to_h
      {
        index: result.index,
        chain_id: chain.id,
        type: self.class.include?(Workflow) ? "Workflow" : "Task",
        tags: self.class.settings[:tags],
        class: self.class.name,
        id:
      }
    end

    def to_s
      Utils::Format.stringify(to_h)
    end

  end
end

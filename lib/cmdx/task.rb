# frozen_string_literal: true

module CMDx
  class Task

    extend Forwardable

    attr_reader :attributes, :errors, :id, :context, :result, :chain
    alias ctx context
    alias res result

    def_delegators :result, :skip!, :fail!, :throw!

    def initialize(context = {})
      Deprecator.restrict(self)

      @attributes = {}
      @errors = Errors.new

      @id = Identifier.generate
      @context = Context.build(context)
      @result = Result.new(self)
      @chain = Chain.build(@result)
    end

    class << self

      def settings(**options)
        @settings ||= begin
          hash =
            if superclass.respond_to?(:settings)
              superclass.settings
            else
              CMDx.configuration.to_h.except(:logger)
            end.transform_values(&:dup)

          hash[:attributes] ||= AttributeRegistry.new
          hash[:deprecate] ||= false
          hash[:tags] ||= []

          hash.merge!(options)
        end
      end

      def register(type, object, ...)
        case type
        when :attribute then settings[:attributes].register(object, ...)
        when :callback then settings[:callbacks].register(object, ...)
        when :coercion then settings[:coercions].register(object, ...)
        when :middleware then settings[:middlewares].register(object, ...)
        when :validator then settings[:validators].register(object, ...)
        else raise "unknown registry type #{type.inspect}"
        end
      end

      def deregister(type, object, ...)
        case type
        when :attribute then settings[:attributes].deregister(object, ...)
        when :callback then settings[:callbacks].deregister(object, ...)
        when :coercion then settings[:coercions].deregister(object, ...)
        when :middleware then settings[:middlewares].deregister(object, ...)
        when :validator then settings[:validators].deregister(object, ...)
        else raise "unknown registry type #{type.inspect}"
        end
      end

      def attributes(...)
        register(:attribute, Attribute.build(...))
      end
      alias attribute attributes

      def optional(...)
        register(:attribute, Attribute.optional(...))
      end

      def required(...)
        register(:attribute, Attribute.required(...))
      end

      def remove_attributes(*names)
        deregister(:attribute, names)
      end
      alias remove_attribute remove_attributes

      CallbackRegistry::TYPES.each do |callback|
        define_method(callback) do |*callables, **options, &block|
          register(:callback, callback, *callables, **options, &block)
        end
      end

      def execute(...)
        task = new(...)
        task.execute(raise: false)
        task.result
      end

      def execute!(...)
        task = new(...)
        task.execute(raise: true)
        task.result
      end

    end

    def execute(raise: false)
      Worker.execute(self, raise:)
    end

    def work
      raise UndefinedMethodError, "undefined method #{self.class.name}#work"
    end

    def logger
      self.class.settings[:logger] || CMDx.configuration.logger
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
      Utils::Format.to_str(to_h)
    end

  end
end

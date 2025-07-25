# frozen_string_literal: true

# class SampleTask < CMDx::Task

#   required :name
#   optional :age, :sex
#   required :billing_address do
#     required :city
#     required :state
#     optional :zip
#   end
#   optional :skipping_address do
#     required :city
#     required :state
#     optional :zip
#   end

#   def call
#     pp self.class.settings[:parameters]
#     pp "-> name: #{name}"
#     pp "-> age: #{age}"
#     pp "-> sex: #{sex}"
#     pp "-> billing_address: #{billing_address}"
#     pp "-> skipping_address: #{skipping_address}"
#   end

# end

# SampleTask.call(name: "John", age: 30); nil

module CMDx
  class Task

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
        @settings ||= CMDx.configuration.to_hash.merge(
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

      def parameter(name, **options, &)
        param = Parameter.parameter(name, **options.merge(klass: self), &)
        settings[:parameters].register(param)
      end

      def parameters(*names, **options, &)
        parameters = Parameter.parameters(*names, **options.merge(klass: self), &)
        settings[:parameters].registry.concat(parameters)
      end

      def optional(*names, **options, &)
        parameters = Parameter.optional(*names, **options.merge(klass: self), &)
        settings[:parameters].registry.concat(parameters)
      end

      def required(*names, **options, &)
        parameters = Parameter.required(*names, **options.merge(klass: self), &)
        settings[:parameters].registry.concat(parameters)
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

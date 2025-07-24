# frozen_string_literal: true

# class SampleTask < CMDx::Task

#   required :name, type: String
#   optional :age

#   def call
#     pp self.class.settings[:parameters]
#     pp name
#     pp age
#   end

# end

# SampleTask.new.call; nil

module CMDx
  class Task

    attr_reader :context

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
        @_settings ||= CMDx.configuration.to_hash.merge(
          parameters: ParameterRegistry.new,
          tags: []
        )
      end

      def settings!(**options)
        settings.merge!(options)
      end

      def register(type, object, ...)
        case type
        when /callback/ then settings[:callbacks].register(type, object, ...)
        when /coercion/ then settings[:coercions].register(type, object, ...)
        when /validator/ then settings[:validators].register(type, object, ...)
        end
      end

      def parameter(name, **options, &)
        options[:klass] = self
        param = Parameter.parameter(name, **options, &)
        settings[:parameters].register(param)
      end

      # rubocop:disable Style/ArgumentsForwarding
      def parameters(*names, **options, &)
        names.each { |name| parameter(name, **options, &) }
      end
      # rubocop:enable Style/ArgumentsForwarding

      def optional(*names, **options, &)
        options[:required] = false
        parameters(*names, **options, &)
      end

      def required(*names, **options, &)
        options[:required] = true
        parameters(*names, **options, &)
      end

      def optional(*attributes, **options, &)
        parameters = Parameter.optional(*attributes, **options.merge(klass: self), &)
        cmd_parameters.registry.concat(parameters)
      end

      def call(...)
        task = new(...)
        TaskProcessor.call(task)
        task.result
      end

      def call!(...)
        task = new(...)
        TaskProcessor.call!(task)
        task.result
      end

    end

    def call
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

    def logger
      Logger.call(self)
    end

  end
end

# frozen_string_literal: true

# class SampleTask < CMDx::Task

#   required :name, type: String
#   optional :age, type: Integer

#   def call
#     pp self.class.cmdx_settings[:parameters]
#   end

# end

# SampleTask.new.call; nil

module CMDx
  class Task

    attr_reader :context

    def initialize(context = {})
      context  = context.context if context.respond_to?(:context)
      @context = Context.new(context)
      @result  = Result.new(self)
    end

    class << self

      def cmdx_settings
        @_cmdx_settings ||= CMDx.configuration.to_hash.merge(
          parameters: Parameters::Registry.new(self),
          tags: []
        )
      end

      def cmdx_settings!(**options)
        cmdx_settings.merge!(options)
      end

      def register(type, object, ...)
        case type
        when /callback/ then cmdx_settings[:callbacks].register(type, object, ...)
        when /coercion/ then cmdx_settings[:coercions].register(type, object, ...)
        when /validator/ then cmdx_settings[:validators].register(type, object, ...)
        end
      end

      def parameter(name, **options, &)
        attribute = Parameters::Attribute.new(name, options, &)
        cmdx_settings[:parameters].register(attribute)
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

      def call(...)
        instance = new(...)
        instance.call
        instance.result
      end

      def call!(...)
        instance = new(...)
        instance.call!
        instance.result
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

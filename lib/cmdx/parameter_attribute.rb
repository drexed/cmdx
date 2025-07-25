# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :schema

    def initialize(schema)
      @schema = schema
    end

    def define_attribute!
      # param = self

      schema.task.class.define_method(schema.signature) do
        rand(100)
        # param.task = self
        # param.value
      end

      schema.task.class.send(:private, schema.signature)
    end

    def validate_attribute!
      # TODO
    end

    # private

    # def value
    #   return @value if defined?(@value)

    #   raise RuntimeError, "a Task or Workflow is required" unless task.is_a?(Task)

    #   @value = ParameterValue.generate!(self)
    # end

    # def validator_allows_nil?(options)
    #   return false unless options.is_a?(Hash) || derived.nil?

    #   case o = options[:allow_nil]
    #   when Symbol, String then task.send(o)
    #   when Proc then o.call(task)
    #   else o
    #   end || false
    # end

    # def validate_value
    #   types = parameter.klass.settings[:validators].keys

    #   parameter.options.slice(*types).each_key do |type|
    #     options = parameter.options[type]
    #     next if validator_allows_nil?(options)
    #     next unless Utils::Condition.evaluate!(task, options)

    #     parameter.klass.settings[:validators].call(type, self, options)
    #   end
    # end

  end
end

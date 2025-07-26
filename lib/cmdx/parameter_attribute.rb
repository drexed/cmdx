# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :schema

    def initialize(schema)
      @schema = schema
      @errors = Errors.new
    end

    def define_attribute!
      attribute = self

      schema.task.class.define_method(schema.signature) { attribute.value }
      schema.task.class.send(:private, schema.signature)
    end

    def validate_attribute!
      # TODO
    end

    private

    def source_value
      return @source_value if defined?(@source_value)

      @source_value =
        case parameter.source
        when Symbol, String then parameter.task.send(parameter.source)
        when Proc then parameter.source.call(parameter.task)
        else
          errors.add(
            schema.signature,
            I18n.t(
              "cmdx.parameters.undefined",
              default: "delegates to undefined source #{parameter.source}",
              source: parameter.source
            )
          )
        end

      if !@source_value.nil? || parameter.parent&.optional? || parameter.optional?
        @source_value
      else
        errors.add(
          schema.signature,
          I18n.t(
            "cmdx.parameters.required",
            default: "is a required parameter"
          )
        )
      end
    end

    # private

    # def value
    #   return @value if defined?(@value)

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

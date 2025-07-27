# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :schema, :errors

    def initialize(schema)
      @schema = schema
      @errors = Errors.new
    end

    def value
      coerced_value
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
        case schema.source
        when Symbol, String then schema.task.send(schema.source)
        when Proc then schema.source.call(schema.task)
        else
          errors.add(
            schema.signature,
            I18n.t(
              "cmdx.parameters.undefined",
              default: "delegates to undefined source #{schema.source}",
              source: schema.source
            )
          )
        end

      if !@source_value.nil? || schema.parent&.optional? || schema.optional?
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

    def derived_value
      return @derived_value if defined?(@derived_value)

      @derived_value =
        case source_value
        when Context, Hash then source_value[schema.name]
        when Proc then source_value.call(schema.task)
        else source_value.send(schema.name)
        end

      return @derived_value unless @derived_value.nil?

      @derived_value =
        case default = schema.options[:default]
        when Proc then default.call(schema.task)
        else default
        end
    end

    def coerced_value
      return @coerced_value if defined?(@coerced_value)
      return @coerced_value = derived_value if schema.type.empty?

      registry = schema.task.class.settings[:coercions]
      last_idx = schema.type.size - 1

      schema.type.each_with_index do |type, i|
        break @coerced_value = registry.coerce!(type, derived_value, schema.options)
      rescue CoercionError
        next if i != last_idx

        values = schema.type.map(&:to_s).join(", ")
        errors.add(
          schema.signature,
          I18n.t(
            "cmdx.coercions.into_any",
            default: "could not coerce into one of: #{values}",
            values:
          )
        )
      end

      @coerced_value
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

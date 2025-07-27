# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :schema, :errors

    def initialize(schema)
      @schema = schema
      @errors = Errors.new
    end

    def value
      return @value if defined?(@value)

      value = source_value!
      return @value = nil unless errors.empty?

      value = derive_value!(value)
      return @value = value if schema.type.empty?

      @value = coerce_value!(value)
    end

    private

    def source_value!
      sourced_value =
        case schema.source
        when Symbol, String then schema.task.send(schema.source)
        when Proc then schema.source.call(schema.task)
        else
          errors.add(
            schema.signature,
            Utils::Locale.t("cmdx.parameters.undefined", source: schema.source)
          )
        end

      return sourced_value if !sourced_value.nil? || schema.parent&.optional? || schema.optional?

      errors.add(
        schema.signature,
        Utils::Locale.t("cmdx.parameters.required")
      )
    end

    def derive_value!(source_value)
      derived_value =
        case source_value
        when Context, Hash then source_value[schema.name]
        when Proc then source_value.call(schema.task)
        else source_value.send(schema.name)
        end

      return derived_value unless derived_value.nil?

      case default = schema.options[:default]
      when Proc then default.call(schema.task)
      else default
      end
    end

    def coerce_value!(derived_value)
      registry = schema.task.class.settings[:coercions]
      last_idx = schema.type.size - 1

      schema.type.find.with_index do |type, i|
        break registry.coerce!(type, derived_value, schema.options)
      rescue CoercionError
        next if i != last_idx

        values = schema.type.map { |t| Utils::Locale.t("cmdx.types.#{t}") }.join(", ")
        errors.add(
          schema.signature,
          Utils::Locale.t("cmdx.coercions.into_any", values:)
        )

        nil
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

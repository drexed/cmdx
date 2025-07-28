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

      sourced_value = source_value!
      return @value = nil unless errors.empty?

      derived_value = derive_value!(sourced_value)
      return @value = nil unless errors.empty?

      coerced_value = coerce_value!(derived_value)
      return @value = nil unless errors.empty?

      validate_value!(coerced_value)
      @value = coerced_value
    end

    private

    def source_value!
      sourced_value =
        case schema.source
        when Proc then schema.source.call(schema.task)
        else schema.task.send(schema.source)
        end

      # TODO: make sure this is correct
      return sourced_value if !sourced_value.nil? || schema.parent&.optional? || schema.optional?

      errors.add(schema.signature, Utils::Locale.t("cmdx.parameters.required"))
    rescue NoMethodError
      errors.add(schema.signature, Utils::Locale.t("cmdx.parameters.undefined", method: schema.source))
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
    rescue NoMethodError
      errors.add(schema.signature, Utils::Locale.t("cmdx.parameters.undefined", method: schema.name))
    end

    def coerce_value!(derived_value)
      return derived_value if schema.type.empty?

      registry = schema.task.class.settings[:coercions]
      last_idx = schema.type.size - 1

      schema.type.find.with_index do |type, i|
        break registry.coerce!(type, derived_value, schema.options)
      rescue CoercionError
        next if i != last_idx

        types = schema.type.map { |t| Utils::Locale.t("cmdx.types.#{t}") }.join(", ")
        errors.add(schema.signature, Utils::Locale.t("cmdx.coercions.into_any", types:))
        nil
      end
    end

    # def validator_allows_nil?(options)
    #   return false unless options.is_a?(Hash) || derived.nil?

    #   case o = options[:allow_nil]
    #   when Symbol, String then task.send(o)
    #   when Proc then o.call(task)
    #   else o
    #   end || false
    # end

    def validate_value!(coerced_value)
      registry = schema.task.class.settings[:validators]

      schema.options.slice(*registry.keys).each_key do |type|
        options = schema.options[type]
        # next if validator_allows_nil?(options)
        # next unless Utils::Condition.evaluate!(task, options)

        registry.validate!(type, coerced_value, options)
      rescue ValidationError => e
        errors.add(schema.signature, e.message)
      end
    end

  end
end

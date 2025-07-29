# frozen_string_literal: true

module CMDx
  class Attribute

    EVALUATOR = proc do |task, value, option|
      case option
      when Symbol, String then task.send(option, value)
      when Proc then option.call(value)
      else option
      end
    end.freeze
    private_constant :EVALUATOR

    extend Forwardable

    def_delegators :parameter, :task

    attr_reader :parameter, :errors

    def initialize(parameter)
      @parameter = parameter
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
        case parameter.source
        when Proc then parameter.source.call(task)
        else task.send(parameter.source)
        end

      # TODO: make sure this is correct
      return sourced_value if !sourced_value.nil? || parameter.parent&.optional? || parameter.optional?

      errors.add(parameter.signature, Locale.t("cmdx.parameters.required"))
    rescue NoMethodError
      errors.add(parameter.signature, Locale.t("cmdx.parameters.undefined", method: parameter.source))
    end

    def derive_value!(source_value)
      derived_value =
        case source_value
        when Context, Hash then source_value[parameter.name]
        when Proc then source_value.call(task)
        else source_value.send(parameter.name)
        end

      return derived_value unless derived_value.nil?

      case default = parameter.options[:default]
      when Proc then default.call(task)
      else default
      end
    rescue NoMethodError
      errors.add(parameter.signature, Locale.t("cmdx.parameters.undefined", method: parameter.name))
    end

    def coerce_value!(derived_value)
      return derived_value if parameter.type.empty?

      registry = task.class.settings[:coercions]
      last_idx = parameter.type.size - 1

      parameter.type.find.with_index do |type, i|
        break registry.coerce!(type, derived_value, parameter.options)
      rescue CoercionError
        next if i != last_idx

        types = parameter.type.map { |t| Locale.t("cmdx.types.#{t}") }.join(", ")
        errors.add(parameter.signature, Locale.t("cmdx.coercions.into_any", types:))
        nil
      end
    end

    def validate_value!(coerced_value)
      registry = task.class.settings[:validators]

      parameter.options.slice(*registry.keys).each_key do |type|
        options = parameter.options[type]

        match =
          if options.is_a?(Hash)
            case options
            in allow_nil:
              allow_nil && coerced_value.nil?
            in if: xif, unless: xunless
              EVALUATOR.call(task, coerced_value, xif) &&
                !EVALUATOR.call(task, coerced_value, xunless)
            in if: xif
              EVALUATOR.call(task, coerced_value, xif)
            in unless: xunless
              !EVALUATOR.call(task, coerced_value, xunless)
            else
              true
            end
          else
            options
          end

        next unless match

        registry.validate!(type, coerced_value, options)
      rescue ValidationError => e
        errors.add(parameter.signature, e.message)
      end
    end

  end
end

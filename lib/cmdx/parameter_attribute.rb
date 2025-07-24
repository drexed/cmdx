# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :parameter

    def initialize(parameter)
      @parameter = parameter
    end

    def self.call(parameter)
      new(parameter).call
    end

    def call
      coerce_value
      validate_value
      define_value
    end

    private

    def source_value
      return @source_value if defined?(@source_value)

      @source_value =
        case parameter.source
        when Symbol, String
          task.send(parameter.source)
        when Proc
          parameter.source.call(parameter)
        else
          raise ValidationError, I18n.t(
            "cmdx.parameters.undefined",
            default: "delegates to undefined source #{parameter.source}",
            source: parameter.source
          )
        end

      return unless @source_value.nil?
      return if parameter.parent&.optional? || parameter.optional?

      raise ValidationError, I18n.t(
        "cmdx.parameters.required",
        default: "is a required parameter"
      )
    end

    def default_value
      case default = parameter.options[:default]
      when Proc
        default.call(parameter)
      else
        default
      end
    end

    def derived_value
      return @derived_value if defined?(@derived_value)

      @derived_value =
        case source_value
        when Symbol, String
          source_value.send(parameter.name)
        when Hash
          source_value[parameter.name]
        when Proc
          source_value.call(parameter)
        end

      @value = default_value if @derived_value.nil?
    end

    def coerce_value
      types = Array(parameter.type)
      tsize = types.size - 1

      types.each_with_index do |key, i|
        break parameter.klass.settings[:coercions].call(task, key, value, options)
      rescue CoercionError => e
        next if tsize != i

        raise(e) if tsize.zero?

        values = types.map(&:to_s).join(", ")
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_any",
          values:,
          default: "could not coerce into one of: #{values}"
        )
      end
    end

    def validate_value
      return if skip_validations_due_to_optional_missing_argument?

      types = CMDx.configuration.validators.registry.keys

      options.slice(*types).each_key do |key|
        opts = options[key]
        next if skip_validator_due_to_allow_nil?(opts)
        next if skip_validator_due_to_conditional?(opts)

        CMDx.configuration.validators.call(task, key, value, opts)
      end
    end

    def define_value
      klass.send(:define_method, parameter.method_name) do
        @cmd_parameter_value_cache ||= {}

        unless @cmd_parameter_value_cache.key?(parameter.method_name)
          begin
            parameter_value = ParameterEvaluator.call(self, parameter)
          rescue CoercionError, ValidationError => e
            parameter.errors.add(parameter.method_name, e.message)
            errors.merge!(parameter.errors.to_hash)
          ensure
            @cmd_parameter_value_cache[parameter.method_name] = parameter_value
          end
        end

        @cmd_parameter_value_cache[parameter.method_name]
      end

      klass.send(:private, parameter.method_name)
    end

  end
end

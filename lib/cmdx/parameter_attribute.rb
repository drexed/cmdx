# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :task, :parameter

    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
    end

    def self.call(task, parameter)
      new(task, parameter).call
    end

    def call
      derived_value
    end

    private

    def source_value
      return @source_value if defined?(@source_value)

      @source_value =
        case parameter.source
        when Symbol, String
          task.send(parameter.source)
        when Proc
          parameter.source.call(task)
        else
          raise ValidationError, I18n.t(
            "cmdx.parameters.undefined",
            default: "delegates to undefined source #{parameter.source}",
            source: parameter.source
          )
        end

      if !@source_value.nil? || parameter.parent&.optional? || parameter.optional?
        @source_value
      else
        raise ValidationError, I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end
    end

    def default_value
      case default = parameter.options[:default]
      when Proc
        default.call(task)
      else
        default
      end
    end

    def derived_value
      return @derived_value if defined?(@derived_value)

      @derived_value =
        case source_value
        when Proc
          source_value.call(task)
        when Context, Hash
          source_value[parameter.name]
        else
          source_value.send(parameter.name)
        end

      if @derived_value.nil?
        @derived_value = default_value
      else
        @derived_value
      end
    end

    # def coerce_value
    #   types = Array(parameter.type)
    #   tsize = types.size - 1

    #   types.each_with_index do |key, i|
    #     break parameter.klass.settings[:coercions].call(task, key, value, options)
    #   rescue CoercionError => e
    #     next if tsize != i

    #     raise(e) if tsize.zero?

    #     values = types.map(&:to_s).join(", ")
    #     raise CoercionError, I18n.t(
    #       "cmdx.coercions.into_any",
    #       values:,
    #       default: "could not coerce into one of: #{values}"
    #     )
    #   end
    # end

    # def validate_value
    #   return if skip_validations_due_to_optional_missing_argument?

    #   types = CMDx.configuration.validators.registry.keys

    #   options.slice(*types).each_key do |key|
    #     opts = options[key]
    #     next if skip_validator_due_to_allow_nil?(opts)
    #     next if skip_validator_due_to_conditional?(opts)

    #     CMDx.configuration.validators.call(task, key, value, opts)
    #   end
    # end

  end
end

# frozen_string_literal: true

module CMDx
  class ParameterAttribute

    attr_reader :task, :parameter, :errors

    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
      @errors    = Set.new
    end

    def self.call(task, parameter)
      new(task, parameter).call
    end

    def call
      source_value
      return unless errors.empty?

      derive_value
      coerce_value
      return unless errors.empty?

      validate_value
      return unless errors.empty?

      derived_value
    end

    private

    def source_value
      return @source_value if defined?(@source_value)

      @source_value =
        case parameter.source
        when Symbol, String then task.send(parameter.source)
        when Proc then parameter.source.call(task)
        else
          errors << I18n.t(
            "cmdx.parameters.undefined",
            default: "delegates to undefined source #{parameter.source}",
            source: parameter.source
          )
        end

      if !@source_value.nil? || parameter.parent&.optional? || parameter.optional?
        @source_value
      else
        errors << I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end
    end

    def derived_value
      return @derived_value if defined?(@derived_value)

      @derived_value =
        case source_value
        when Context, Hash then source_value[parameter.name]
        when Proc then source_value.call(task)
        else source_value.send(parameter.name)
        end

      if @derived_value.nil?
        @derived_value =
          case default = parameter.options[:default]
          when Proc then default.call(task)
          else default
          end
      else
        @derived_value
      end
    end
    alias derive_value derived_value

    def coerce_value
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
    end

    def validator_allows_nil?(options)
      return false unless options.is_a?(Hash) || derived_value.nil?

      case o = options[:allow_nil]
      when Symbol, String then task.send(o)
      when Proc then o.call(task)
      else o
      end || false
    end

    def validate_value
      types = parameter.klass.settings[:validators].keys

      parameter.options.slice(*types).each_key do |type|
        options = parameter.options[type]
        next if validator_allows_nil?(options)
        next unless Utils::Condition.call(task, options)

        parameter.klass.settings[:validators].call(type, self, options)
      end
    end

  end
end

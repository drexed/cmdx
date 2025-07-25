# frozen_string_literal: true

module CMDx
  class ParameterValue

    attr_reader :task, :parameter, :errors

    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
      @errors    = Set.new
    end

    def source
      return @source if defined?(@source)

      @source =
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

      if !@source.nil? || parameter.parent&.optional? || parameter.optional?
        @source
      else
        errors << I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end
    end

    def derived
      return @derived if defined?(@derived)

      @derived =
        case source
        when Context, Hash then source[parameter.name]
        when Proc then source.call(task)
        else source.send(parameter.name)
        end

      if @derived.nil?
        @derived =
          case default = parameter.options[:default]
          when Proc then default.call(task)
          else default
          end
      else
        @derived
      end
    end

    # def coerce_value
    #   #   types = Array(parameter.type)
    #   #   tsize = types.size - 1

    #   #   types.each_with_index do |key, i|
    #   #     break parameter.klass.settings[:coercions].call(task, key, value, options)
    #   #   rescue CoercionError => e
    #   #     next if tsize != i

    #   #     raise(e) if tsize.zero?

    #   #     values = types.map(&:to_s).join(", ")
    #   #     raise CoercionError, I18n.t(
    #   #       "cmdx.coercions.into_any",
    #   #       values:,
    #   #       default: "could not coerce into one of: #{values}"
    #   #     )
    #   #   end
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

# frozen_string_literal: true

module CMDx
  class ParameterValue

    attr_reader :parameter, :errors

    def initialize(parameter)
      @parameter = parameter
      @errors    = Set.new
    end

    def self.generate!(parameter)
      new(parameter).value
    end

    def value
      return @value if defined?(@value)

      @value =
        if errors.empty?
          derived_value
        else
          nil
        end
    end

    private

    def source_value
      return @source_value if defined?(@source_value)

      @source_value =
        case parameter.source
        when Symbol, String then parameter.task.send(parameter.source)
        when Proc then parameter.source.call(parameter.task)
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
        when Proc then source_value.call(parameter.task)
        else source_value.send(parameter.name)
        end

      if @derived_value.nil?
        @derived_value =
          case default = parameter.options[:default]
          when Proc then default.call(parameter.task)
          else default
          end
      else
        @derived_value
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

  end
end

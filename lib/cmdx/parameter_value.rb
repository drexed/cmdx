# frozen_string_literal: true

module CMDx
  class ParameterValue

    cmdx_attr_delegator :parent, :method_source, :name, :options, :required?, :optional?, :type,
                        to: :parameter,
                        private: true

    # @return [CMDx::Task] The task instance being processed
    attr_reader :task

    # @return [CMDx::Parameter] The parameter definition being processed
    attr_reader :parameter

    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
    end

    def call
      coerce!.tap { validate! }
    end

    private

    def source_defined?
      task.respond_to?(method_source, true) || task.cmdx_try(method_source)
    end

    def source
      return @source if defined?(@source)

      unless source_defined?
        raise ValidationError, I18n.t(
          "cmdx.parameters.undefined",
          default: "delegates to undefined method #{method_source}",
          source: method_source
        )
      end

      @source = task.cmdx_try(method_source)
    end

    def source_value?
      return false if source.nil?

      source.cmdx_respond_to?(name, true)
    end

    def source_value_required?
      return false if parent&.optional? && source.nil?

      required? && !source_value?
    end

    def value
      return @value if defined?(@value)

      if source_value_required?
        raise ValidationError, I18n.t(
          "cmdx.parameters.required",
          default: "is a required parameter"
        )
      end

      @value = source.cmdx_try(name)
      return @value unless @value.nil? && options.key?(:default)

      @value = task.cmdx_yield(options[:default])
    end

    def coerce!
      types = Array(type)
      tsize = types.size - 1

      types.each_with_index do |key, i|
        break CMDx.configuration.coercions.call(task, key, value, options)
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

    def skip_validations_due_to_optional_missing_argument?
      optional? && value.nil? && !source.nil? && !source.cmdx_respond_to?(name, true)
    end

    def skip_validator_due_to_conditional?(key)
      opts = options[key]
      opts.is_a?(Hash) && !task.cmdx_eval(opts)
    end

    def skip_validator_due_to_allow_nil?(key)
      opts = options[key]
      opts.is_a?(Hash) && opts[:allow_nil] && value.nil?
    end

    def validate!
      return if skip_validations_due_to_optional_missing_argument?

      types = CMDx.configuration.validators.registry.keys

      options.slice(*types).each_key do |key|
        next if skip_validator_due_to_allow_nil?(key)
        next if skip_validator_due_to_conditional?(key)

        CMDx.configuration.validators.call(task, key, value, options)
      end
    end

  end
end

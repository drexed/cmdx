# frozen_string_literal: true

module CMDx
  class ParameterValue

    __cmdx_attr_delegator :parent, :method_source, :name, :options, :required?, :optional?, :type, to: :parameter, private: true

    attr_reader :task, :parameter

    def initialize(task, parameter)
      @task      = task
      @parameter = parameter
    end

    def call
      coerce!.tap { validate! }
    end

    private

    def source_defined?
      task.respond_to?(method_source, true) || task.__cmdx_try(method_source)
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

      @source = task.__cmdx_try(method_source)
    end

    def source_value?
      return false if source.nil?

      source.__cmdx_respond_to?(name, true)
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

      @value = source.__cmdx_try(name)
      return @value unless @value.nil? && options.key?(:default)

      @value = task.__cmdx_yield(options[:default])
    end

    def coerce!
      types = Array(type)
      tsize = types.size - 1

      types.each_with_index do |t, i|
        break case t.to_sym
              when :array then Coercions::Array
              when :big_decimal then Coercions::BigDecimal
              when :boolean then Coercions::Boolean
              when :complex then Coercions::Complex
              when :date then Coercions::Date
              when :datetime then Coercions::DateTime
              when :float then Coercions::Float
              when :hash then Coercions::Hash
              when :integer then Coercions::Integer
              when :rational then Coercions::Rational
              when :string then Coercions::String
              when :time then Coercion::Time
              when :virtual then Coercions::Virtual
              else raise UnknownCoercionError, "unknown coercion #{t}"
              end.call(value, options)
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
      optional? && value.nil? && !source.nil? && !source.__cmdx_respond_to?(name, true)
    end

    def skip_validator_due_to_conditional?(key)
      opts = options[key]
      opts.is_a?(Hash) && !task.__cmdx_eval(opts)
    end

    def skip_validator_due_to_allow_nil?(key)
      opts = options[key]
      opts.is_a?(Hash) && opts[:allow_nil] && value.nil?
    end

    def validate!
      return if skip_validations_due_to_optional_missing_argument?

      options.each_key do |key|
        next if skip_validator_due_to_allow_nil?(key)
        next if skip_validator_due_to_conditional?(key)

        case key.to_sym
        when :custom then Validators::Custom
        when :exclusion then Validators::Exclusion
        when :format then Validators::Format
        when :inclusion then Validators::Inclusion
        when :length then Validators::Length
        when :numeric then Validators::Numeric
        when :presence then Validators::Presence
        end&.call(value, options)
      end
    end

  end
end

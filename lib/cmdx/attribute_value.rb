# frozen_string_literal: true

module CMDx
  # Manages the value lifecycle for a single attribute within a task.
  # Handles value sourcing, derivation, coercion, and validation through
  # a coordinated pipeline that ensures data integrity and type safety.
  class AttributeValue

    extend Forwardable

    # @rbs @attribute: Attribute
    attr_reader :attribute

    def_delegators :attribute, :task, :parent, :name, :options, :types, :source, :method_name, :required?
    def_delegators :task, :attributes, :errors

    # Creates a new attribute value manager for the given attribute.
    #
    # @param attribute [Attribute] The attribute to manage values for
    #
    # @example
    #   attr = Attribute.new(:user_id, required: true)
    #   attr_value = AttributeValue.new(attr)
    #
    # @rbs (Attribute attribute) -> void
    def initialize(attribute)
      @attribute = attribute
    end

    # Retrieves the current value for this attribute from the task's attributes.
    #
    # @return [Object, nil] The current attribute value or nil if not set
    #
    # @example
    #   attr_value.value # => "john_doe"
    #
    # @rbs () -> untyped
    def value
      attributes[method_name]
    end

    # Generates the attribute value through the complete pipeline:
    # sourcing, derivation, coercion, and storage.
    #
    # @return [Object, nil] The generated value or nil if generation failed
    #
    # @example
    #   attr_value.generate # => 42
    #
    # @rbs () -> untyped
    def generate
      return value if attributes.key?(method_name)

      sourced_value = source_value
      return if errors.for?(method_name)

      derived_value = derive_value(sourced_value)
      return if errors.for?(method_name)

      coerced_value = coerce_value(derived_value)
      transformed_value = transform_value(coerced_value)
      return if errors.for?(method_name)

      attributes[method_name] = transformed_value
    end

    # Validates the current attribute value against configured validators.
    #
    # @raise [ValidationError] When validation fails (handled internally)
    #
    # @example
    #   attr_value.validate
    #   # Validates value against :presence, :format, etc.
    #
    # @rbs () -> void
    def validate
      registry = task.class.settings[:validators]

      options.slice(*registry.keys).each do |type, opts|
        registry.validate(type, task, value, opts)
      rescue ValidationError => e
        errors.add(method_name, e.message)
        nil
      end
    end

    private

    # Retrieves the source value for this attribute from various sources.
    #
    # @return [Object, nil] The sourced value or nil if unavailable
    #
    # @raise [NoMethodError] When the source method doesn't exist
    #
    # @example
    #   # Sources from task method, proc, or direct value
    #   source_value # => "raw_value"
    # @rbs () -> untyped
    def source_value
      sourced_value =
        case source
        when Symbol then task.send(source)
        when Proc then task.instance_eval(&source)
        else source.respond_to?(:call) ? source.call(task) : source
        end

      if required? && (parent.nil? || parent&.required?)
        case sourced_value
        when Context, Hash then sourced_value.key?(name)
        when Proc then true # Cannot be determined
        else sourced_value.respond_to?(name, true)
        end || errors.add(method_name, Locale.t("cmdx.attributes.required"))
      end

      sourced_value
    rescue NoMethodError
      errors.add(method_name, Locale.t("cmdx.attributes.undefined", method: source))
      nil
    end

    # Retrieves the default value for this attribute if configured.
    #
    # @return [Object, nil] The default value or nil if not configured
    #
    # @example
    #   # Default can be symbol, proc, or direct value
    #   -> { rand(100) } # => 23
    #
    # @rbs () -> untyped
    def default_value
      default = options[:default]

      if default.is_a?(Symbol) && task.respond_to?(default, true)
        task.send(default)
      elsif default.is_a?(Proc)
        task.instance_eval(&default)
      elsif default.respond_to?(:call)
        default.call(task)
      else
        default
      end
    end

    # Derives the actual value from the source value using various strategies.
    #
    # @param source_value [Object] The source value to derive from
    #
    # @return [Object, nil] The derived value or nil if derivation failed
    #
    # @raise [NoMethodError] When the derivation method doesn't exist
    #
    # @example
    #   # Derives from hash key, method call, or proc execution
    #   context.user_id # => 42
    #
    # @rbs (untyped source_value) -> untyped
    def derive_value(source_value)
      derived_value =
        case source_value
        when Context, Hash then source_value[name]
        when Symbol then source_value.send(name)
        when Proc then task.instance_exec(name, &source_value)
        else source_value.call(task, name) if source_value.respond_to?(:call)
        end

      derived_value.nil? ? default_value : derived_value
    rescue NoMethodError
      errors.add(method_name, Locale.t("cmdx.attributes.undefined", method: name))
      nil
    end

    # Transforms the derived value using the transform option.
    #
    # @param derived_value [Object] The value to transform
    #
    # @return [Object, nil] The transformed value or nil if transformation failed
    #
    # @example
    #   :downcase # => "hello"
    #
    # @rbs (untyped derived_value) -> untyped
    def transform_value(derived_value)
      transform = options[:transform]

      if transform.is_a?(Symbol) && derived_value.respond_to?(transform, true)
        derived_value.send(transform)
      elsif transform.respond_to?(:call)
        transform.call(derived_value)
      else
        derived_value
      end
    end

    # Coerces the derived value to the expected type(s) using the coercion registry.
    #
    # @param transformed_value [Object] The value to coerce
    #
    # @return [Object, nil] The coerced value or nil if coercion failed
    #
    # @raise [CoercionError] When coercion fails (handled internally)
    #
    # @example
    #   # Coerces "42" to Integer, "true" to Boolean, etc.
    #   coerce_value("42") # => 42
    #
    # @rbs (untyped transformed_value) -> untyped
    def coerce_value(transformed_value)
      return transformed_value if types.empty?

      registry = task.class.settings[:coercions]
      last_idx = types.size - 1

      types.find.with_index do |type, i|
        break registry.coerce(type, task, transformed_value, options)
      rescue CoercionError => e
        next if i != last_idx

        message =
          if last_idx.zero?
            e.message
          else
            tl = types.map { |t| Locale.t("cmdx.types.#{t}") }.join(", ")
            Locale.t("cmdx.coercions.into_any", types: tl)
          end

        errors.add(method_name, message)
        nil
      end
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Resolves a single attribute value through the pipeline:
  # source -> derive -> default -> coerce -> transform -> validate.
  # Supports nested children for Hash-typed attributes.
  module ValueResolver

    # Resolves all attributes for a task execution.
    #
    # @param attributes [Array<Attribute>] compiled attribute specs
    # @param context [Context] execution context
    # @param coercions [Hash] coercion registry
    # @param validators [Hash] validator registry
    # @param errors [Errors] error collector
    # @param task [Object, nil] task instance for method-based callables
    # @return [Hash{Symbol => Object}] resolved attribute values
    #
    # @rbs (Array[Attribute] attributes, Context context, Hash[Symbol, untyped] coercions, Hash[Symbol, untyped] validators, Errors errors, ?untyped? task, ?String? prefix) -> Hash[Symbol, untyped]
    def self.resolve_all(attributes, context, coercions:, validators:, errors:, task: nil, prefix: nil) # rubocop:disable Metrics/ParameterLists
      result = {}

      attributes.each do |attr|
        key = prefix ? :"#{prefix}.#{attr.name}" : attr.name
        value = resolve_one(attr, context, coercions:, validators:, errors:, task:, error_key: key)
        result[attr.reader_name] = value
      end

      result
    end

    # @rbs (Attribute attr, Context context, coercions: Hash[Symbol, untyped], validators: Hash[Symbol, untyped], errors: Errors, ?task: untyped?, ?error_key: Symbol?) -> untyped
    def self.resolve_one(attr, context, coercions:, validators:, errors:, task: nil, error_key: nil) # rubocop:disable Metrics/ParameterLists
      error_key ||= attr.name
      value = source_value(attr, context, task)
      value = derive_value(attr, value, context, task)
      value = default_value(attr, value, context, task)
      value = coerce_value(attr, value, coercions, errors, error_key)
      value = transform_value(attr, value, task)
      validate_value(attr, value, validators, errors, error_key, context, task)

      if attr.nested? && value.is_a?(Hash)
        nested_ctx = Context.new(value)
        nested = resolve_all(attr.children, nested_ctx, coercions:, validators:, errors:, task:, prefix: error_key.to_s)
        value = nested
      end

      context[attr.name] = value
      value
    end

    # @rbs (Attribute attr, Context context, untyped? task) -> untyped
    def self.source_value(attr, context, task)
      if attr.from
        if attr.from.is_a?(Symbol) && task.respond_to?(attr.from, true)
          task.send(attr.from)
        else
          context[attr.from]
        end
      else
        context[attr.name]
      end
    end

    # @rbs (Attribute attr, untyped value, Context context, untyped? task) -> untyped
    def self.derive_value(attr, value, context, task)
      return value unless attr.derive

      callable = attr.derive
      if callable.is_a?(Symbol) && task.respond_to?(callable, true)
        task.send(callable)
      elsif callable.respond_to?(:call)
        callable.call(value, context)
      else
        value
      end
    end

    # @rbs (Attribute attr, untyped value, Context context, untyped? task) -> untyped
    def self.default_value(attr, value, _context, task)
      return value unless value.nil?
      return nil if attr.default.nil?

      d = attr.default
      if d.is_a?(Proc)
        d.call
      elsif d.is_a?(Symbol) && task.respond_to?(d, true)
        task.send(d)
      else
        d
      end
    end

    # @rbs (Attribute attr, untyped value, Hash[Symbol, untyped] coercions, Errors errors, Symbol error_key) -> untyped
    def self.coerce_value(attr, value, coercions, errors, error_key)
      return value if value.nil? || attr.type_keys.empty?

      attr.type_keys.each do |type_key|
        coercer = coercions[type_key]
        next unless coercer

        begin
          return coercer.call(value)
        rescue CMDx::CoercionError => e
          errors.add(error_key, e.message, :coercion)
          return value
        rescue StandardError
          next
        end
      end

      value
    end

    # @rbs (Attribute attr, untyped value, untyped? task) -> untyped
    def self.transform_value(attr, value, task)
      return value unless attr.transform

      t = attr.transform
      if t.is_a?(Symbol) && task.respond_to?(t, true)
        task.send(t, value)
      elsif t.respond_to?(:call)
        t.call(value)
      else
        value
      end
    end

    # @rbs (Attribute attr, untyped value, Hash[Symbol, untyped] validators, Errors errors, Symbol error_key, Context context, untyped? task) -> void
    def self.validate_value(attr, value, validators, errors, error_key, context, task) # rubocop:disable Metrics/ParameterLists
      attr.validations.each do |v|
        validator = validators[v[:name]]
        next unless validator
        next unless validator_applies?(v[:options], value, context, task)

        message = validator.call(value, **v[:options])
        errors.add(error_key, message, v[:name]) if message
      end
    end

    # @rbs (Hash[Symbol, untyped] options, untyped value, Context context, untyped? task) -> bool
    def self.validator_applies?(options, value, _context, task)
      return false if options[:allow_nil] && value.nil?

      if options[:if]
        condition = options[:if]
        return false unless evaluate_condition(condition, task)
      end

      if options[:unless]
        condition = options[:unless]
        return false if evaluate_condition(condition, task)
      end

      true
    end

    # @rbs (untyped condition, untyped? task) -> bool
    def self.evaluate_condition(condition, task) # rubocop:disable Naming/PredicateMethod
      case condition
      when Symbol then task.respond_to?(condition, true) ? !!task.send(condition) : false
      when Proc then !!condition.call
      else !!condition
      end
    end

    private_class_method :source_value, :derive_value, :default_value,
                         :coerce_value, :transform_value, :validate_value,
                         :validator_applies?, :evaluate_condition

  end
end

# frozen_string_literal: true

module CMDx
  # Defines a single task attribute with its full processing pipeline:
  # source resolution -> coercion -> transformation -> validation.
  class Attribute

    RESERVED_NAMES = %i[
      id context ctx result res errors work execute execute! rollback
      skip! fail! success! throw! dry_run? logger class freeze frozen?
    ].to_set.freeze

    VALIDATOR_KEYS = %i[presence absence format inclusion exclusion length numeric].freeze
    OPTION_KEYS = %i[required default type source transform as prefix suffix description desc if unless].freeze
    COERCION_OPTION_KEYS = %i[strptime precision].freeze

    attr_reader :name, :options, :children

    # @param name [Symbol]
    # @param options [Hash]
    # @param children [CMDx::AttributeSet, nil]
    def initialize(name, options = {}, children: nil)
      @name = name.to_sym
      @options = options.freeze
      @children = children
    end

    # @return [Boolean]
    def required?
      !!@options[:required]
    end

    # @return [Symbol] the method name for the accessor
    def accessor_name
      return @options[:as].to_sym if @options[:as]

      base = @name.to_s
      prefix = @options[:prefix]
      suffix = @options[:suffix]

      prefix = prefix == true ? "context_" : prefix.to_s if prefix
      suffix = suffix == true ? "_context" : suffix.to_s if suffix

      :"#{prefix}#{base}#{suffix}"
    end

    # @return [String, nil]
    def description
      @options[:description] || @options[:desc]
    end

    # Process this attribute for a given task: resolve source, coerce,
    # transform, validate. Returns the final value and appends any
    # errors to the provided ErrorSet.
    #
    # @param task [CMDx::Task]
    # @param error_set [CMDx::ErrorSet]
    # @param task_coercions [Hash, nil]
    # @param task_validators [Hash, nil]
    # @return [Object] the processed value
    def process(task, error_set, task_coercions: nil, task_validators: nil)
      value = resolve_source(task)
      value = apply_default(task, value)

      if required_for?(task) && value.nil?
        error_set.add(@name, Messages.resolve("attribute.required"))
        return value
      end

      value = coerce(value, error_set, task_coercions: task_coercions)
      return value if error_set.for?(@name)

      value = transform(task, value)

      validate(value, task, error_set, task_validators: task_validators)

      if @children && value.is_a?(Hash) && !error_set.for?(@name)
        process_children(task, value, error_set,
                         task_coercions: task_coercions,
                         task_validators: task_validators)
      end

      value
    end

    # @return [Hash] introspection schema
    def to_schema
      schema = { required: required? }
      schema[:types] = Array(@options[:type]) if @options[:type]
      schema[:default] = @options[:default] if @options.key?(:default)
      schema[:description] = description if description
      schema[:source] = @options[:source] if @options[:source]

      VALIDATOR_KEYS.each do |key|
        schema[key] = @options[key] if @options.key?(key)
      end

      schema[:children] = @children.schema if @children

      schema
    end

    private

    def resolve_source(task)
      source = @options[:source]

      case source
      when nil, :context
        task.context[@name]
      when Symbol
        src = Callable.resolve(source, task)
        src.respond_to?(:[]) ? src[@name] : src
      else
        Callable.resolve(source, task)
      end
    end

    def apply_default(task, value)
      return value unless value.nil? && @options.key?(:default)

      default = @options[:default]
      case default
      when Symbol then Callable.resolve(default, task)
      when Proc   then default.call
      else default
      end
    end

    def required_for?(task)
      return false unless required?

      req_if = @options[:if]
      req_unless = @options[:unless]

      return !Callable.evaluate(req_unless, task) if req_unless
      return Callable.evaluate(req_if, task) if req_if

      true
    end

    def coerce(value, error_set, task_coercions: nil)
      return value unless @options[:type] && !value.nil?

      Coercions.coerce(@options[:type], value, @options, task_registry: task_coercions)
    rescue CoercionError => e
      error_set.add(@name, e.message)
      value
    end

    def transform(task, value)
      return value unless @options[:transform] && !value.nil?

      Callable.resolve(@options[:transform], task, value)
    end

    def validate(value, task, error_set, task_validators: nil)
      return if value.nil? && !required?

      VALIDATOR_KEYS.each do |key|
        next unless @options.key?(key)

        msg = Validators.validate(key, value, @options[key],
                                  task: task, task_registry: task_validators)
        error_set.add(@name, msg) if msg
      end

      custom_validators(value, task, error_set, task_validators: task_validators)
    end

    def custom_validators(value, task, error_set, task_validators: nil)
      @options.each do |key, opts|
        next if VALIDATOR_KEYS.include?(key)
        next if OPTION_KEYS.include?(key)
        next if COERCION_OPTION_KEYS.include?(key)

        msg = Validators.validate(key, value, opts,
                                  task: task, task_registry: task_validators)
        error_set.add(@name, msg) if msg
      end
    end

    def process_children(task, parent_value, error_set, task_coercions: nil, task_validators: nil)
      @children.each_attribute do |child_attr|
        child_value = parent_value[child_attr.name]
        child_attr.process(task, error_set,
                           task_coercions: task_coercions,
                           task_validators: task_validators)
        task.context[child_attr.name] = child_value if child_value
      end
    end

  end
end

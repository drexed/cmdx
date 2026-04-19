# frozen_string_literal: true

module CMDx
  # A single declared task input. Holds declaration options (`:source`,
  # `:default`, `:required`, `:coerce`, validators, `:transform`, etc.) and
  # owns the resolution pipeline that produces the value the task will read
  # through the generated accessor.
  class Input

    attr_reader :name, :children

    # @param name [Symbol, String] input key (symbolized)
    # @param children [Array<Input>] nested child inputs resolved from this one's value
    # @param options [Hash{Symbol => Object}] declaration options
    # @option options [String] :description (also accepts `:desc`)
    # @option options [Symbol] :as overrides the accessor name
    # @option options [Boolean, String] :prefix prefix for the accessor name
    # @option options [Boolean, String] :suffix suffix for the accessor name
    # @option options [Symbol, Proc, #call] :source (`:context`) where to fetch from
    # @option options [Object, Symbol, Proc, #call] :default
    # @option options [Symbol, Proc, #call] :transform mutator applied after coercion
    # @option options [Symbol, Proc, #call] :if
    # @option options [Symbol, Proc, #call] :unless
    # @option options [Boolean] :required
    def initialize(name, children: EMPTY_ARRAY, **options)
      @name     = name.to_sym
      @children = children.freeze
      @options  = options.freeze
    end

    # @return [String, nil]
    def description
      @options[:description] || @options[:desc]
    end

    # @return [Symbol, nil]
    def as
      @options[:as]
    end

    # @return [Boolean, String, nil]
    def prefix
      @options[:prefix]
    end

    # @return [Boolean, String, nil]
    def suffix
      @options[:suffix]
    end

    # @return [Symbol, Proc, #call]
    def source
      @options[:source] || :context
    end

    # @return [Object, Symbol, Proc, #call, nil]
    def default
      @options[:default]
    end

    # @return [Symbol, Proc, #call, nil]
    def transform
      @options[:transform]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_if
      @options[:if]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_unless
      @options[:unless]
    end

    # @return [Boolean]
    def required
      @options.fetch(:required, false)
    end

    # Computed accessor/reader method name. Uses `:as` when provided,
    # otherwise combines `:prefix`, `name`, and `:suffix` around the source.
    #
    # @return [Symbol]
    def accessor_name
      return as if as

      @accessor_name ||= begin
        prefix_str =
          case prefix
          when true
            "#{source}_"
          when ::String
            prefix
          end
        suffix_str =
          case suffix
          when true
            "_#{source}"
          when ::String
            suffix
          end

        :"#{prefix_str}#{name}#{suffix_str}"
      end
    end

    # @return [Symbol] backing ivar used by the generated reader method
    def ivar_name
      @ivar_name ||= :"@_input_#{accessor_name}"
    end

    # Evaluates required-ness against `task`, respecting `:if`/`:unless`.
    # When called without a task, returns the static `:required` flag.
    #
    # @param task [Task, nil]
    # @return [Boolean]
    def required?(task = nil)
      return false unless required
      return true if task.nil?
      return false unless Util.satisfied?(condition_if, condition_unless, task)

      true
    end

    # Fetches + coerces + transforms + validates the value from its
    # configured `:source` on `task`. Missing-but-required inputs add a
    # validation error to `task.errors`.
    #
    # @param task [Task]
    # @return [Object, nil, Coercions::Failure] the resolved value
    def resolve(task)
      value, key_provided = resolve_with_key(task)
      run_pipeline(value, key_provided, task)
    end

    # Same as {#resolve} but fetches the value from `parent_value` (used for
    # nested child inputs) instead of the declared `:source`.
    #
    # @param parent_value [#[], #key?, Object] the parent input's resolved value
    # @param task [Task]
    # @return [Object, nil, Coercions::Failure]
    def resolve_from_parent(parent_value, task)
      value, key_provided = resolve_from_parent_with_key(parent_value)
      run_pipeline(value, key_provided, task)
    end

    # @return [Hash{Symbol => Object}] serialized schema used by `inputs_schema`
    def to_h
      {
        name: accessor_name,
        description:,
        required: required?,
        options: @options,
        children: children.map(&:to_h)
      }
    end

    private

    def run_pipeline(value, key_provided, task)
      if required?(task) && !key_provided
        task.errors.add(accessor_name, I18nProxy.t("cmdx.attributes.required"))
        return
      end

      value = apply_default(task) if value.nil?
      return if value.nil?

      @coercions ||= task.class.coercions.extract(@options)
      value = task.class.coercions.coerce(task, accessor_name, value, @coercions)
      return if value.is_a?(Coercions::Failure)

      value = apply_transform(value, task) if transform
      @validators ||= task.class.validators.extract(@options)
      task.class.validators.validate(task, accessor_name, value, @validators)

      value
    end

    def resolve_with_key(task)
      case source
      when :context
        [task.context[name], task.context.key?(name)]
      when Symbol
        obj = task.send(source)
        return [nil, false] if obj.nil?

        fetch_by_name(obj)
      when Proc
        [task.instance_exec(&source), true]
      else
        return [source.call(task), true] if source.respond_to?(:call)

        raise ArgumentError, "source must be a Symbol, Proc, or respond to #call"
      end
    end

    def resolve_from_parent_with_key(parent_value)
      return [nil, false] unless parent_value.respond_to?(:[])

      fetch_by_name(parent_value)
    end

    def fetch_by_name(obj)
      if obj.respond_to?(:key?)
        if obj.key?(name)
          [obj[name], true]
        elsif obj.key?(name_str = name.to_s)
          [obj[name_str], true]
        else
          [nil, false]
        end
      elsif obj.respond_to?(:[])
        # Without #key? we cannot distinguish "key absent" from "value is nil",
        # so an explicit nil is treated as not provided (triggers default/required).
        value = obj[name]
        [value, !value.nil?]
      elsif obj.respond_to?(name)
        [obj.send(name), true]
      else
        [nil, false]
      end
    end

    def apply_default(task)
      return if default.nil?

      case default
      when Symbol
        task.send(default)
      when Proc
        task.instance_exec(&default)
      else
        return default unless default.respond_to?(:call)

        default.call(task)
      end
    end

    def apply_transform(value, task)
      case transform
      when Symbol
        if value.respond_to?(transform)
          value.send(transform)
        else
          task.send(transform, value)
        end
      when Proc
        task.instance_exec(value, &transform)
      else
        return transform.call(value, task) if transform.respond_to?(:call)

        raise ArgumentError, "transform must be a Symbol, Proc, or respond to #call"
      end
    end

  end
end

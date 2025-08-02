# frozen_string_literal: true

module CMDx
  class Attribute

    AFFIX = proc do |value, &block|
      value == true ? block.call : value
    end.freeze
    private_constant :AFFIX

    attr_accessor :task

    attr_reader :name, :options, :children, :parent, :types, :errors

    def initialize(name, options = {}, &)
      @parent   = options.delete(:parent)
      @required = options.delete(:required) || false
      @types    = Array(options.delete(:types) || options.delete(:type))

      @name     = name
      @options  = options
      @children = []

      @value  = nil
      @errors = Set.new

      instance_eval(&) if block_given?
    end

    class << self

      def define(name, ...)
        new(name, ...)
      end

      def defines(*names, **options, &)
        if names.none?
          raise ArgumentError, "no attributes given"
        elsif (names.size > 1) && options.key?(:as)
          raise ArgumentError, ":as option only supports one attribute per definition"
        end

        names.filter_map { |name| define(name, **options, &) }
      end

      def optional(*names, **options, &)
        defines(*names, **options.merge(required: false), &)
      end

      def required(*names, **options, &)
        defines(*names, **options.merge(required: true), &)
      end

    end

    def optional?
      !required?
    end

    def required?
      !!@required
    end

    def source
      @source ||=
        parent&.method_name ||
        case value = options[:source]
        when Symbol, String then value.to_sym
        when Proc then task.instance_eval(&value)
        else
          if value.respond_to?(:call)
            value.call(task)
          else
            value || :context
          end
        end
    end

    def method_name
      @method_name ||= options[:as] || begin
        prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
        suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

        "#{prefix}#{name}#{suffix}".strip.to_sym
      end
    end

    def value
      return task.attributes[method_name] if task.attributes.key?(method_name)

      sourced_value = source_value!
      return task.attributes[method_name] unless errors.empty?

      derived_value = derive_value!(sourced_value)
      return task.attributes[method_name] unless errors.empty?

      coerced_value = coerce_value!(derived_value)
      return task.attributes[method_name] unless errors.empty?

      validate_value!(coerced_value)
      task.attributes[method_name] = coerced_value
    end

    def define_and_verify!
      define_and_verify

      children.each do |child|
        child.task = task
        child.define_and_verify!
      end
    end

    private

    def attribute(name, **options, &)
      attr = self.class.define(name, **options.merge(parent: self), &)
      children.push(attr)
    end

    def attributes(*names, **options, &)
      attrs = self.class.defines(*names, **options.merge(parent: self), &)
      children.concat(attrs)
    end

    def optional(*names, **options, &)
      attributes(*names, **options.merge(required: false), &)
    end

    def required(*names, **options, &)
      attributes(*names, **options.merge(required: true), &)
    end

    def define_and_verify
      raise "#{task.class.name}##{method_name} already defined" if task.respond_to?(method_name)

      v = value # HACK: hydrate and verify the attribute value
      task.class.define_method(method_name) { v }
      task.class.send(:private, method_name)

      # task.instance_eval(<<-RUBY, __FILE__, __LINE__ + 1)
      #   def #{method_name}
      #     attributes[:#{method_name}]
      #   end
      #   private :#{method_name}
      # RUBY
    end

    def source_value!
      sourced_value =
        case source
        when String, Symbol then task.send(source)
        when Proc then task.instance_exec(&source)
        else
          if source.respond_to?(:call)
            source.call(task, source)
          else
            source
          end
        end

      if required? && (parent.nil? || parent&.required?)
        case sourced_value
        when Context, Hash then sourced_value.key?(name)
        else sourced_value.respond_to?(name, true)
        end || errors.add(Utils::Locale.translate!("cmdx.attributes.required"))
      end

      sourced_value
    rescue NoMethodError
      errors.add(Utils::Locale.translate!("cmdx.attributes.undefined", method: source))
      nil
    end

    def default_value
      opt = options[:default]

      if opt.is_a?(Proc)
        task.instance_exec(&opt)
      elsif opt.respond_to?(:call)
        opt.call(task)
      else
        opt
      end
    end

    def derive_value!(source_value)
      derived_value =
        case source_value
        when String, Symbol then source_value.send(name)
        when Context, Hash then source_value[name]
        when Proc then task.instance_exec(source_value, &source_value)
        else source_value.call(task, source_value) if source_value.respond_to?(:call)
        end

      derived_value.nil? ? default_value : derived_value
    rescue NoMethodError
      errors.add(Utils::Locale.translate!("cmdx.attributes.undefined", method: name))
      nil
    end

    def coerce_value!(derived_value)
      return derived_value if types.empty?

      registry = task.class.settings[:coercions]
      last_idx = types.size - 1

      types.find.with_index do |type, i|
        break registry.coerce!(type, task, derived_value, options)
      rescue CoercionError
        next if i != last_idx

        tl = types.map { |t| Utils::Locale.translate!("cmdx.types.#{t}") }.join(", ")
        errors.add(Utils::Locale.translate!("cmdx.coercions.into_any", types: tl))
        nil
      end
    end

    def validate_value!(coerced_value)
      registry = task.class.settings[:validators]

      options.slice(*registry.keys).each_key do |type|
        registry.validate!(type, task, coerced_value, options[type])
      rescue ValidationError => e
        errors.add(e.message)
        nil
      end
    end

  end
end

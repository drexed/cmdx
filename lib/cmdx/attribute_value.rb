# frozen_string_literal: true

module CMDx
  class AttributeValue

    extend Forwardable

    attr_reader :attribute

    def_delegators :attribute, :task, :parent, :name, :options, :types, :source, :method_name, :required?
    def_delegators :task, :attributes, :errors

    def initialize(attribute)
      @attribute = attribute
    end

    def value
      attributes[method_name]
    end

    def generate
      return value if attributes.key?(method_name)

      sourced_value = source_value
      return if errors.for?(method_name)

      derived_value = derive_value(sourced_value)
      return if errors.for?(method_name)

      coerced_value = coerce_value(derived_value)
      return if errors.for?(method_name)

      attributes[method_name] = coerced_value
    end

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

    def source_value
      sourced_value =
        case source
        when Symbol then task.send(source)
        when Proc then task.instance_exec(&source)
        else source.respond_to?(:call) ? source.call(task) : source
        end

      if required? && (parent.nil? || parent&.required?)
        case sourced_value
        when Context, Hash then sourced_value.key?(name)
        when Proc then true # Cannot be determined
        else sourced_value.respond_to?(name, true)
        end || errors.add(method_name, Locale.translate("cmdx.attributes.required"))
      end

      sourced_value
    rescue NoMethodError
      errors.add(method_name, Locale.translate("cmdx.attributes.undefined", method: source))
      nil
    end

    def default_value
      default = options[:default]

      if default.is_a?(Symbol) && task.respond_to?(default, true)
        task.send(default)
      elsif default.is_a?(Proc)
        task.instance_exec(&default)
      elsif default.respond_to?(:call)
        default.call(task)
      else
        default
      end
    end

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
      errors.add(method_name, Locale.translate("cmdx.attributes.undefined", method: name))
      nil
    end

    def coerce_value(derived_value)
      return derived_value if attribute.types.empty?

      registry = task.class.settings[:coercions]
      last_idx = attribute.types.size - 1

      attribute.types.find.with_index do |type, i|
        break registry.coerce(type, task, derived_value, options)
      rescue CoercionError
        next if i != last_idx

        tl = attribute.types.map { |t| Locale.translate("cmdx.types.#{t}") }.join(", ")
        errors.add(method_name, Locale.translate("cmdx.coercions.into_any", types: tl))
        nil
      end
    end

  end
end

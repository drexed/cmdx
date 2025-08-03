# frozen_string_literal: true

module CMDx
  class AttributeValue

    extend Forwardable

    def_delegators :attribute, :task, :parent, :name, :options, :types, :source, :method_name, :required?
    def_delegators :task, :attributes, :errors

    attr_reader :attribute

    def initialize(attribute)
      @attribute = attribute
    end

    def self.value(attribute)
      new(attribute).value
    end

    def value
      return attributes[method_name] if attributes.key?(method_name)

      sourced_value = source_value!
      return if errors.for?(method_name)

      derived_value = derive_value!(sourced_value)
      return if errors.for?(method_name)

      coerced_value = coerce_value!(derived_value)
      return if errors.for?(method_name)

      validate_value!(coerced_value)
      attributes[method_name] = coerced_value
    end

    private

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
        end || errors.add(method_name, Utils::Locale.translate!("cmdx.attributes.required"))
      end

      sourced_value
    rescue NoMethodError
      errors.add(method_name, Utils::Locale.translate!("cmdx.attributes.undefined", method: source))
      nil
    end

    def default_value
      default = options[:default]

      if default.is_a?(Proc)
        task.instance_exec(&default)
      elsif default.respond_to?(:call)
        default.call(task)
      else
        default
      end
    end

    def derive_value!(source_value)
      derived_value =
        case source_value
        when String, Symbol then source_value.send(name)
        when Context, Hash then source_value[name]
        when Proc then task.instance_exec(name, &source_value)
        else source_value.call(task) if source_value.respond_to?(:call)
        end

      derived_value.nil? ? default_value : derived_value
    rescue NoMethodError
      errors.add(method_name, Utils::Locale.translate!("cmdx.attributes.undefined", method: name))
      nil
    end

    def coerce_value!(derived_value)
      return derived_value if attribute.types.empty?

      registry = task.class.settings[:coercions]
      last_idx = attribute.types.size - 1

      attribute.types.find.with_index do |type, i|
        break registry.coerce!(type, task, derived_value, options)
      rescue CoercionError
        next if i != last_idx

        tl = attribute.types.map { |t| Utils::Locale.translate!("cmdx.types.#{t}") }.join(", ")
        errors.add(method_name, Utils::Locale.translate!("cmdx.coercions.into_any", types: tl))
        nil
      end
    end

    def validate_value!(coerced_value)
      registry = task.class.settings[:validators]

      options.slice(*registry.keys).each do |type, opts|
        registry.validate!(type, task, coerced_value, opts)
      rescue ValidationError => e
        errors.add(method_name, e.message)
        nil
      end
    end

  end
end

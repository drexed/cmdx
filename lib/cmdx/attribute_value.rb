# frozen_string_literal: true

module CMDx
  class AttributeValue

    extend Forwardable

    def_delegators :attribute, :task

    attr_reader :attribute

    def initialize(attribute)
      @attribute = attribute
    end

    def value
      return task.attributes[attribute.method_name] if task.attributes.key?(attribute.method_name)

      sourced_value = source_value!
      return task.attributes[attribute.method_name] unless task.errors.for?(attribute.method_name)

      derived_value = derive_value!(sourced_value)
      return task.attributes[attribute.method_name] unless task.errors.for?(attribute.method_name)

      coerced_value = coerce_value!(derived_value)
      return task.attributes[attribute.method_name] unless task.errors.for?(attribute.method_name)

      validate_value!(coerced_value)
      task.attributes[attribute.method_name] = coerced_value
    end

    private

    def source_value!
      sourced_value =
        case attribute.source
        when String, Symbol then task.send(attribute.source)
        when Proc then task.instance_exec(&attribute.source)
        else
          if attribute.source.respond_to?(:call)
            attribute.source.call(task, attribute.source)
          else
            attribute.source
          end
        end

      if attribute.required? && (attribute.parent.nil? || attribute.parent&.required?)
        case sourced_value
        when Context, Hash then sourced_value.key?(attribute.name)
        else sourced_value.respond_to?(attribute.name, true)
        end || task.errors.add(
          attribute.method_name,
          Utils::Locale.translate!("cmdx.attributes.required")
        )
      end

      sourced_value
    rescue NoMethodError
      task.errors.add(
        attribute.method_name,
        Utils::Locale.translate!("cmdx.attributes.undefined", method: attribute.source)
      )
      nil
    end

    def default_value
      opt = attribute.options[:default]

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
        when String, Symbol then source_value.send(attribute.name)
        when Context, Hash then source_value[attribute.name]
        when Proc then task.instance_exec(source_value, &source_value)
        else source_value.call(task, source_value) if source_value.respond_to?(:call)
        end

      derived_value.nil? ? default_value : derived_value
    rescue NoMethodError
      task.errors.add(
        attribute.method_name,
        Utils::Locale.translate!("cmdx.attributes.undefined", method: attribute.name)
      )
      nil
    end

    def coerce_value!(derived_value)
      return derived_value if attribute.types.empty?

      registry = task.class.settings[:coercions]
      last_idx = attribute.types.size - 1

      attribute.types.find.with_index do |type, i|
        break registry.coerce!(type, task, derived_value, attribute.options)
      rescue CoercionError
        next if i != last_idx

        tl = attribute.types.map { |t| Utils::Locale.translate!("cmdx.types.#{t}") }.join(", ")
        task.errors.add(attribute.method_name, Utils::Locale.translate!("cmdx.coercions.into_any", types: tl))
        nil
      end
    end

    def validate_value!(coerced_value)
      registry = task.class.settings[:validators]

      attribute.options.slice(*registry.keys).each do |type, opts|
        registry.validate!(type, task, coerced_value, opts)
      rescue ValidationError => e
        task.errors.add(attribute.method_name, e.message)
        nil
      end
    end

  end
end

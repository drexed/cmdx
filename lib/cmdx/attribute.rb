# frozen_string_literal: true

module CMDx
  class Attribute

    extend Forwardable

    def_delegators :parameter, :task

    attr_reader :parameter, :errors

    def initialize(parameter)
      @parameter = parameter
      @errors = Set.new
    end

    def value
      return @value if defined?(@value)

      sourced_value = source_value!
      return @value = nil unless errors.empty?

      derived_value = derive_value!(sourced_value)
      return @value = nil unless errors.empty?

      coerced_value = coerce_value!(derived_value)
      return @value = nil unless errors.empty?

      validate_value!(coerced_value)
      @value = coerced_value
    end

    private

    def source_value!
      sourced_value =
        case parameter.source
        when String, Symbol then task.send(parameter.source)
        when Proc then task.instance_exec(&parameter.source)
        else
          if parameter.source.respond_to?(:call)
            parameter.source.call(task, parameter.source)
          else
            parameter.source
          end
        end

      if parameter.required? && (parameter.parent.nil? || parameter.parent&.required?)
        case sourced_value
        when Context, Hash then sourced_value.key?(parameter.name)
        else sourced_value.respond_to?(parameter.name, true)
        end || errors.add(Locale.translate!("cmdx.parameters.required"))
      end

      sourced_value
    rescue NoMethodError
      errors.add(Locale.translate!("cmdx.parameters.undefined", method: parameter.source))
      nil
    end

    def default_value
      opt = parameter.options[:default]

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
        when String, Symbol then source_value.send(parameter.name)
        when Context, Hash then source_value[parameter.name]
        when Proc then task.instance_exec(source_value, &source_value)
        else source_value.call(task, source_value) if source_value.respond_to?(:call)
        end

      derived_value.nil? ? default_value : derived_value
    rescue NoMethodError
      errors.add(Locale.translate!("cmdx.parameters.undefined", method: parameter.name))
      nil
    end

    def coerce_value!(derived_value)
      return derived_value if parameter.type.empty?

      registry = task.class.settings[:coercions]
      last_idx = parameter.type.size - 1

      parameter.type.find.with_index do |type, i|
        break registry.coerce!(type, task, derived_value, parameter.options)
      rescue CoercionError
        next if i != last_idx

        types = parameter.type.map { |t| Utils::Locale.translate!("cmdx.types.#{t}") }.join(", ")
        errors.add(Locale.translate!("cmdx.coercions.into_any", types:))
        nil
      end
    end

    def validate_value!(coerced_value)
      registry = task.class.settings[:validators]

      parameter.options.slice(*registry.keys).each_key do |type|
        registry.validate!(type, task, coerced_value, parameter.options[type])
      rescue ValidationError => e
        errors.add(e.message)
        nil
      end
    end

  end
end

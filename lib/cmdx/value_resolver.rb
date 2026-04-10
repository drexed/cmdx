# frozen_string_literal: true

module CMDx
  # Resolves a single attribute's value through the pipeline:
  # source → derive → default → coerce → transform
  module ValueResolver

    # Resolves the value for an attribute.
    #
    # @param attr [Attribute] the attribute definition
    # @param task [Task] the task instance
    # @param context [Context] the execution context
    #
    # @return [Object] the resolved value
    #
    # @rbs (Attribute attr, untyped task, Context context) -> untyped
    def self.call(attr, task, context)
      value = source(attr, task, context)
      value = derive(attr, task, value)
      value = apply_default(attr, task, value)
      value = coerce(attr, value)
      transform(attr, task, value)
    end

    # Resolves the raw value from context or a :from source.
    #
    # @rbs (Attribute attr, untyped task, Context context) -> untyped
    def self.source(attr, task, context)
      if attr.from
        if task.respond_to?(attr.from, true)
          task.__send__(attr.from)
        else
          context[attr.from]
        end
      else
        context[attr.name]
      end
    end

    # Applies a derivation callable if configured.
    #
    # @rbs (Attribute attr, untyped task, untyped value) -> untyped
    def self.derive(attr, task, value)
      return value unless attr.derive

      Utils::Call.invoke(attr.derive, task, value)
    end

    # Applies the default value if the current value is nil.
    #
    # @rbs (Attribute attr, untyped task, untyped value) -> untyped
    def self.apply_default(attr, task, value)
      return value unless value.nil? && attr.has_default?

      default = attr.default
      case default
      when Proc   then task.instance_exec(&default)
      when Symbol then task.__send__(default)
      else default
      end
    end

    # Coerces the value through the registered coercion type.
    #
    # @rbs (Attribute attr, untyped value) -> untyped
    def self.coerce(attr, value)
      return value unless attr.typed? && !value.nil?

      coercer = CoercionRegistry.new.resolve(attr.type)
      coercer.call(value)
    end

    # Applies a transformation callable if configured.
    #
    # @rbs (Attribute attr, untyped task, untyped value) -> untyped
    def self.transform(attr, task, value)
      return value unless attr.transform

      Utils::Call.invoke(attr.transform, task, value)
    end

  end
end

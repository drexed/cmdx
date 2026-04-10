# frozen_string_literal: true

module CMDx
  # Task-level deprecation policy resolved from {Definition#deprecate}.
  module Deprecator

    extend self

    RAISE_REGEXP = /\Araise\z/
    private_constant :RAISE_REGEXP

    LOG_REGEXP = /\Alog\z/
    private_constant :LOG_REGEXP

    WARN_REGEXP = /\Awarn\z/
    private_constant :WARN_REGEXP

    EVAL = proc do |target, callable|
      case callable
      when NilClass, FalseClass, TrueClass then !!callable
      when RAISE_REGEXP, LOG_REGEXP, WARN_REGEXP then callable
      when Symbol then target.send(callable)
      when Proc then target.instance_eval(&callable)
      else
        raise "cannot evaluate #{callable.inspect}" unless callable.respond_to?(:call)

        callable.call(target)
      end
    end.freeze
    private_constant :EVAL

    # @param task [Task]
    # @return [void]
    def restrict(task)
      setting = task.class.definition.deprecate
      return unless setting

      case type = EVAL.call(task, setting)
      when NilClass, FalseClass then nil
      when TrueClass, RAISE_REGEXP then raise DeprecationError, "#{task.class.name} usage prohibited"
      when LOG_REGEXP then task.logger.warn { "DEPRECATED: migrate to a replacement or discontinue use" }
      when WARN_REGEXP then warn("[#{task.class.name}] DEPRECATED: migrate to a replacement or discontinue use", category: :deprecated)
      else raise "unknown deprecation type #{type.inspect}"
      end
    end

  end
end

# frozen_string_literal: true

module CMDx
  module Utils
    module Condition

      extend self

      EVAL = proc do |target, callable, *args, **kwargs, &block|
        case callable
        when NilClass, FalseClass, TrueClass then !!callable
        when Symbol then target.send(callable, *args, **kwargs, &block)
        when Proc then target.instance_exec(*args, **kwargs, &callable)
        else
          raise "cannot evaluate #{callable.inspect}" unless callable.respond_to?(:call)

          callable.call(*args, **kwargs, &block)
        end
      end.freeze
      private_constant :EVAL

      def evaluate(target, options, ...)
        case options
        in if: if_cond, unless: unless_cond
          EVAL.call(target, if_cond, ...) && !EVAL.call(target, unless_cond, ...)
        in if: if_cond
          EVAL.call(target, if_cond, ...)
        in unless: unless_cond
          !EVAL.call(target, unless_cond, ...)
        else
          true
        end
      end

    end
  end
end

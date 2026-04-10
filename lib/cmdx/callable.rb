# frozen_string_literal: true

module CMDx
  # Utility module for resolving callable forms used across the framework.
  # Supports: Symbol (method on receiver), Proc/Lambda, Class/Module (.call),
  # and instances responding to #call.
  module Callable

    # Pre-resolve a non-symbol callable to a Proc at registration time.
    # Symbols are returned as-is (they need an instance to resolve).
    #
    # @param callable [Symbol, Proc, Class, #call] the callable to wrap
    # @return [Symbol, Proc] a symbol or a proc ready to call
    def self.wrap(callable)
      case callable
      when Symbol, Proc then callable
      when Class
        if callable.instance_method(:initialize).arity.zero?
          instance = callable.new
          ->(*args, **kw, &blk) { instance.call(*args, **kw, &blk) }
        else
          ->(*args, **kw, &blk) { callable.call(*args, **kw, &blk) }
        end
      when Module
        ->(*args, **kw, &blk) { callable.call(*args, **kw, &blk) }
      else
        if callable.respond_to?(:call)
          ->(*args, **kw, &blk) { callable.call(*args, **kw, &blk) }
        else
          callable
        end
      end
    end

    # Resolve and invoke a callable at runtime.
    #
    # @param callable [Symbol, Proc, Class, #call] the callable to invoke
    # @param receiver [Object] the object for symbol resolution (method receiver)
    # @param args [Array] positional arguments
    # @param kwargs [Hash] keyword arguments
    # @param block [Proc] optional block to pass through
    # @return [Object] the result of the call
    def self.resolve(callable, receiver, ...)
      case callable
      when Symbol then receiver.send(callable, ...)
      when Proc   then callable.call(...)
      else
        if callable.respond_to?(:call)
          callable.call(...)
        else
          callable
        end
      end
    end

    # Evaluate a condition (if/unless) in the context of a receiver.
    #
    # @param condition [Symbol, Proc, Class, #call, nil] the condition
    # @param receiver [Object] the object for symbol resolution
    # @return [Boolean]
    def self.condition_met?(condition, receiver)
      return true if condition.nil?

      !!resolve(condition, receiver)
    end

    class << self

      alias evaluate condition_met?

    end

  end
end

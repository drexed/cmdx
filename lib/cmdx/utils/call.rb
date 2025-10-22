# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for invoking callable objects with different invocation strategies.
    #
    # This module provides a unified interface for calling methods, procs, and other
    # callable objects on target objects, handling the appropriate invocation method
    # based on the callable type.
    module Call

      extend self

      # Invokes a callable object on the target with the given arguments.
      #
      # @param target [Object] The target object to invoke the callable on
      # @param callable [Symbol, Proc, #call] The callable to invoke
      # @param args [Array] Positional arguments to pass to the callable
      # @param kwargs [Hash] Keyword arguments to pass to the callable
      # @param &block [Proc, nil] Block to pass to the callable
      #
      # @return [Object] The result of invoking the callable
      #
      # @raise [RuntimeError] When the callable cannot be invoked
      #
      # @example Invoking a method by symbol
      #   Call.invoke(user, :name)
      #   Call.invoke(user, :update, { name: 'John' })
      # @example Invoking a proc
      #   proc = ->(name) { "Hello #{name}" }
      #   Call.invoke(user, proc, 'John')
      # @example Invoking a callable object
      #   callable = MyCallable.new
      #   Call.invoke(user, callable, 'data')
      #
      # @rbs (untyped target, (Symbol | Proc | untyped) callable, *untyped args, **untyped kwargs) ?{ () -> untyped } -> untyped
      def invoke(target, callable, *args, **kwargs, &)
        if callable.is_a?(Symbol)
          target.send(callable, *args, **kwargs, &)
        elsif callable.is_a?(Proc)
          target.instance_exec(*args, **kwargs, &callable)
        elsif callable.respond_to?(:call)
          callable.call(*args, **kwargs, &)
        else
          raise "cannot invoke #{callable}"
        end
      end

    end
  end
end

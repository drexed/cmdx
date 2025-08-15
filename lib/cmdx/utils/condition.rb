# frozen_string_literal: true

module CMDx
  module Utils
    # Provides conditional evaluation utilities for CMDx tasks and workflows.
    #
    # This module handles conditional logic evaluation with support for `if` and `unless`
    # conditions using various callable types including symbols, procs, and objects
    # responding to `call`.
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

      # Evaluates conditional logic based on provided options.
      #
      # Supports both `if` and `unless` conditions, with `unless` taking precedence
      # when both are specified. Returns true if no conditions are provided.
      #
      # @param target [Object] The target object to evaluate conditions against
      # @param options [Hash] Conditional options hash
      # @option options [Object] :if Condition that must be true for evaluation to succeed
      # @option options [Object] :unless Condition that must be false for evaluation to succeed
      # @param args [Array] Additional arguments passed to condition evaluation
      # @param kwargs [Hash] Additional keyword arguments passed to condition evaluation
      # @param block [Proc, nil] Optional block passed to condition evaluation
      #
      # @return [Boolean] true if conditions are met, false otherwise
      #
      # @raise [RuntimeError] When a callable cannot be evaluated
      #
      # @example Basic if condition
      #   Condition.evaluate(user, if: :active?)
      #   # => true if user.active? returns true
      # @example Unless condition
      #   Condition.evaluate(user, unless: :blocked?)
      #   # => true if user.blocked? returns false
      # @example Combined conditions
      #   Condition.evaluate(user, if: :verified?, unless: :suspended?)
      #   # => true if user.verified? is true AND user.suspended? is false
      # @example With arguments and block
      #   Condition.evaluate(user, if: ->(u) { u.has_permission?(:admin) }, :admin)
      #   # => true if the proc returns true when called with user and :admin
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

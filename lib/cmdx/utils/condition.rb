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

      # @rbs EVAL: Proc
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
      #
      # @rbs (untyped target, Hash[Symbol, untyped] options, *untyped) ?{ () -> untyped } -> bool
      def evaluate(target, options, ...)
        has_if = options.key?(:if)
        has_unless = options.key?(:unless)

        if has_if && has_unless
          EVAL.call(target, options[:if], ...) && !EVAL.call(target, options[:unless], ...)
        elsif has_if
          EVAL.call(target, options[:if], ...)
        elsif has_unless
          !EVAL.call(target, options[:unless], ...)
        else
          true
        end
      end

    end
  end
end

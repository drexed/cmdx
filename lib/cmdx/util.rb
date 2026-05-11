# frozen_string_literal: true

module CMDx
  # Shared helpers for resolving `:if` / `:unless` conditional options across
  # tasks, callbacks, inputs, outputs, validators, and deprecations. Normalizes
  # booleans, symbols (method names), procs, and call-ables into a truth value.
  module Util

    extend self

    # Evaluates a condition against `receiver`, dispatching by type.
    #
    # @param condition [Boolean, nil, Symbol, Proc, #call] `:if`/`:unless`-style gate, method name, or callable evaluated against `receiver`
    # @param receiver [Object] object the condition runs against (usually a Task)
    # @param args [Array<Object>] extra arguments forwarded to the condition
    # @return [Boolean, Object] truthiness result (Procs `instance_exec` on receiver)
    # @raise [ArgumentError] when the condition is not a supported type
    def evaluate(condition, receiver, *args)
      case condition
      when FalseClass, NilClass
        false
      when TrueClass
        true
      when Symbol
        receiver.send(condition, *args)
      when Proc
        receiver.instance_exec(*args, &condition)
      else
        return condition.call(receiver, *args) if condition.respond_to?(:call)

        raise ArgumentError,
          "condition must be a Symbol, Proc, or respond to #call (got #{condition.class})"
      end
    end

    # Evaluates an `:if`-style condition. `nil` is treated as "always true".
    #
    # @param condition [Boolean, nil, Symbol, Proc, #call] gate to check
    # @param receiver [Object] object the condition runs against
    # @param args [Array<Object>] extra arguments forwarded to the condition
    # @return [Boolean] true when `condition` is nil or evaluates truthy
    def if?(condition, receiver, *args)
      return true if condition.nil?

      evaluate(condition, receiver, *args)
    end

    # Evaluates an `:unless`-style condition. `nil` is treated as "always true".
    #
    # @param condition [Boolean, nil, Symbol, Proc, #call] gate to check
    # @param receiver [Object] object the condition runs against
    # @param args [Array<Object>] extra arguments forwarded to the condition
    # @return [Boolean] true when `condition` is nil or evaluates falsy
    def unless?(condition, receiver, *args)
      return true if condition.nil?

      !evaluate(condition, receiver, *args)
    end

    # Combines `:if` and `:unless` gates. Used across the framework to decide
    # whether a conditional feature (callback, retry, validator, etc.) should run.
    #
    # @param condition_if [Boolean, nil, Symbol, Proc, #call] `:if` gate
    # @param condition_unless [Boolean, nil, Symbol, Proc, #call] `:unless` gate
    # @param receiver [Object] object the conditions run against
    # @param args [Array<Object>] extra arguments forwarded to both conditions
    # @return [Boolean] true only when both gates pass
    def satisfied?(condition_if, condition_unless, receiver, *args)
      if?(condition_if, receiver, *args) &&
        unless?(condition_unless, receiver, *args)
    end

  end
end

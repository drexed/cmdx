# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions to Object that provide CMDx-specific utility methods.
    #
    # ObjectExtensions adds safe method calling, conditional evaluation,
    # and value yielding capabilities to all Ruby objects. These methods
    # are prefixed with `cmdx_` to avoid conflicts with existing methods.
    #
    # @example Safe method calling
    #   object.cmdx_try(:some_method)  # Returns nil if method doesn't exist
    #   object.cmdx_try(proc { expensive_calculation })  # Calls proc safely
    #
    # @example Conditional evaluation
    #   object.cmdx_eval(if: :valid?)       # True if object.valid? is true
    #   object.cmdx_eval(unless: :empty?)   # True unless object.empty? is true
    #   object.cmdx_eval(if: :valid?, unless: :processed?)  # Combined conditions
    #
    # @example Value yielding
    #   object.cmdx_yield(:name)           # Returns object.name if method exists, otherwise :name
    #   object.cmdx_yield(-> { compute })  # Executes lambda and returns result
    #
    # @see Task Tasks that use these object extensions
    # @see Parameter Parameters that leverage object extensions
    module ObjectExtensions

      # Store original respond_to? method before aliasing
      alias cmdx_respond_to? respond_to?

      # Safely attempt to call a method or execute a proc on an object.
      #
      # This method provides safe method calling with fallback behavior.
      # It handles method calls, proc execution, and hash key access gracefully.
      #
      # @param key [Symbol, String, Proc] method name or callable to attempt
      # @param args [Array] arguments to pass to the method/proc (passed via splat)
      # @return [Object, nil] result of method call, proc execution, or nil if not possible
      #
      # @example Method calling
      #   user.cmdx_try(:name)              # => "John" or nil
      #   user.cmdx_try(:age, 25)           # => calls user.age(25) or nil
      #
      # @example Proc execution
      #   user.cmdx_try(-> { expensive_calc }) # => executes lambda
      #   user.cmdx_try(proc { |x| x * 2 }, 5) # => 10
      #
      # @example Hash access
      #   hash = {name: "John"}
      #   hash.cmdx_try(:name)              # => "John"
      def cmdx_try(key, ...)
        if key.is_a?(Proc)
          return instance_eval(&key) unless is_a?(Module) || key.inspect.include?("(lambda)")

          key.call(...)
        elsif respond_to?(key, true)
          send(key, ...)
        elsif is_a?(Hash)
          cmdx_fetch(key)
        end
      end

      # Evaluate conditional options for execution control.
      #
      # This method evaluates :if and :unless conditions to determine
      # whether something should proceed. Used extensively in callbacks
      # and conditional parameter processing.
      #
      # @param options [Hash] conditional options
      # @option options [Symbol, Proc] :if condition that must be true
      # @option options [Symbol, Proc] :unless condition that must be false
      # @option options [Boolean] :default default value if no conditions (default: true)
      # @return [Boolean] true if conditions are met
      #
      # @example Simple conditions
      #   user.cmdx_eval(if: :admin?)       # => true if user.admin? is true
      #   user.cmdx_eval(unless: :guest?)   # => true unless user.guest? is true
      #
      # @example Combined conditions
      #   user.cmdx_eval(if: :active?, unless: :banned?)  # => active AND not banned
      #
      # @example With procs
      #   user.cmdx_eval(if: -> { Time.now.monday? }) # => true if today is Monday
      def cmdx_eval(options = {})
        if options[:if] && options[:unless]
          cmdx_try(options[:if]) && !cmdx_try(options[:unless])
        elsif options[:if]
          cmdx_try(options[:if])
        elsif options[:unless]
          !cmdx_try(options[:unless])
        else
          options.fetch(:default, true)
        end
      end

      # Yield a value by attempting to call it as a method or executing it.
      #
      # This method provides intelligent value resolution - if the key is
      # a method name and the object responds to it, call the method.
      # Otherwise, try to execute it as a proc or return the value as-is.
      #
      # @param key [Object] value to yield, method name, or callable
      # @param args [Array] arguments to pass if calling method/proc (passed via splat)
      # @return [Object] yielded value
      #
      # @example Method yielding
      #   user.cmdx_yield(:name)           # => calls user.name if method exists, otherwise returns :name
      #   user.cmdx_yield("email")         # => calls user.email if method exists, otherwise returns "email"
      #
      # @example Proc yielding
      #   user.cmdx_yield(-> { timestamp }) # => executes lambda
      #   hash.cmdx_yield({key: "value"})   # => tries hash access
      #
      # @example Direct values
      #   user.cmdx_yield(42)              # => 42
      #   user.cmdx_yield("literal")       # => "literal"
      def cmdx_yield(key, ...)
        if key.is_a?(Symbol) || key.is_a?(String)
          return key unless respond_to?(key, true)

          send(key, ...)
        elsif is_a?(Hash) || key.is_a?(Proc)
          cmdx_try(key, ...)
        else
          key
        end
      end

      # Call an object if it responds to call, otherwise return itself.
      #
      # This method provides safe callable execution - if the object
      # can be called (like a proc or lambda), call it with the given
      # arguments. Otherwise, return the object unchanged.
      #
      # @param args [Array] arguments to pass to call method (passed via splat)
      # @return [Object] result of calling or the object itself
      #
      # @example Callable objects
      #   proc = -> { "Hello" }
      #   proc.cmdx_invoke                   # => "Hello"
      #
      # @example Non-callable objects
      #   string = "Hello"
      #   string.cmdx_invoke                 # => "Hello"
      #
      # @example With arguments
      #   adder = ->(a, b) { a + b }
      #   adder.cmdx_invoke(2, 3)           # => 5
      def cmdx_invoke(...)
        return self unless respond_to?(:call)

        call(...)
      end

    end
  end
end

# Extend all objects with CMDx utility methods
Object.include(CMDx::CoreExt::ObjectExtensions)

# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions for Ruby's Object class that provide flexible method calling and evaluation utilities.
    # These extensions are automatically included in all objects when CMDx is loaded, providing
    # safe method invocation, conditional evaluation, and dynamic yielding capabilities.
    module ObjectExtensions

      alias cmdx_respond_to? respond_to?

      # Safely tries to call a method, evaluate a proc, or access a hash key.
      # Provides flexible invocation that handles different types of callables gracefully.
      #
      # @param key [Symbol, String, Proc, Object] the method name, proc, or hash key to try
      # @param args [Array] arguments to pass to the method or proc
      #
      # @return [Object, nil] the result of the method call, proc evaluation, or hash access; nil if not found
      #
      # @example Try calling a method
      #   "hello".cmdx_try(:upcase) # => "HELLO"
      #   "hello".cmdx_try(:missing) # => nil
      #
      # @example Try evaluating a proc
      #   obj.cmdx_try(-> { self.class.name }) # => "String"
      #
      # @example Try accessing a hash key
      #   {name: "John"}.cmdx_try(:name) # => "John"
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

      # Evaluates conditional options using :if and :unless logic.
      # Supports both method names and procs for conditional evaluation.
      #
      # @param options [Hash] evaluation options
      # @option options [Symbol, Proc] :if condition that must be truthy
      # @option options [Symbol, Proc] :unless condition that must be falsy
      # @option options [Object] :default (true) default value when no conditions are specified
      #
      # @return [Boolean] true if conditions are met, false otherwise
      #
      # @example Evaluate with if condition
      #   user.cmdx_eval(if: :active?) # => true if user.active? is truthy
      #
      # @example Evaluate with unless condition
      #   user.cmdx_eval(unless: :banned?) # => true if user.banned? is falsy
      #
      # @example Evaluate with both conditions
      #   user.cmdx_eval(if: :active?, unless: :banned?) # => true if active and not banned
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

      # Yields or returns a value based on its type, with smart method calling.
      # Handles symbols/strings as method names, procs/hashes via cmdx_try, and returns other values as-is.
      #
      # @param key [Symbol, String, Proc, Hash, Object] the value to yield or method to call
      # @param args [Array] arguments to pass to method calls
      #
      # @return [Object] the result of method call, proc evaluation, or the value itself
      #
      # @example Yield a method call
      #   "hello".cmdx_yield(:upcase) # => "HELLO"
      #
      # @example Yield a static value
      #   obj.cmdx_yield("static") # => "static"
      #
      # @example Yield a proc
      #   obj.cmdx_yield(-> { Time.now }) # => 2023-01-01 12:00:00 UTC
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

      # Invokes the object if it responds to :call, otherwise returns the object itself.
      # Useful for handling both callable and non-callable objects uniformly.
      #
      # @param args [Array] arguments to pass to the call method
      #
      # @return [Object] the result of calling the object, or the object itself if not callable
      #
      # @example Invoke a proc
      #   proc { "hello" }.cmdx_invoke # => "hello"
      #
      # @example Invoke a non-callable object
      #   "hello".cmdx_invoke # => "hello"
      def cmdx_invoke(...)
        return self unless respond_to?(:call)

        call(...)
      end

    end
  end
end

Object.include(CMDx::CoreExt::ObjectExtensions)

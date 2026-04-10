# frozen_string_literal: true

module CMDx
  # Registry of middleware classes for a task.
  # Middleware wraps execution in an onion-style call chain.
  # Uses copy-on-write for safe inheritance across task classes.
  class MiddlewareRegistry

    # @rbs @stack: Array[untyped]
    attr_reader :stack

    # @rbs (?Array[untyped]? stack) -> void
    def initialize(stack = nil)
      @stack = stack || []
    end

    # Adds a middleware to the stack.
    #
    # @param klass [Class] the middleware class (must respond to .call or #call)
    # @param args [Array] arguments to pass to the middleware
    #
    # @rbs (untyped klass, *untyped args) -> void
    def register(klass, *args)
      stack << { klass:, args: }
    end

    # Removes a middleware from the stack.
    #
    # @param klass [Class] the middleware class to remove
    #
    # @rbs (untyped klass) -> void
    def deregister(klass)
      stack.reject! { |entry| entry[:klass] == klass }
    end

    # Executes the middleware stack around the given block.
    #
    # @param task [Task] the task instance
    # @yield the inner work to wrap
    #
    # @return [Object] the block's return value
    #
    # @rbs (untyped task) { () -> untyped } -> untyped
    def call(task, &block)
      return yield if stack.empty?

      chain = stack.reverse.reduce(block) do |next_middleware, entry|
        yielded = false
        proc do
          entry[:klass].call(task, *entry[:args]) do
            yielded = true
            next_middleware.call
          end
          raise MiddlewareError, "#{entry[:klass]} did not yield" unless yielded
        end
      end
      chain.call
    end

    # @return [Boolean] true if any middleware is registered
    #
    # @rbs () -> bool
    def any?
      !stack.empty?
    end

    # @return [MiddlewareRegistry] a duplicated registry for child classes
    #
    # @rbs () -> MiddlewareRegistry
    def for_child
      self.class.new(stack.dup)
    end

  end
end

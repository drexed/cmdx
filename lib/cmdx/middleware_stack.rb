# frozen_string_literal: true

module CMDx
  # Class-level middleware stack with onion-model execution.
  # Cached per class; invalidated on register/deregister.
  module MiddlewareStack

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@middleware_stack, middleware_stack.dup)
        subclass.instance_variable_set(:@middleware_chain, nil)
      end

      # @return [Array]
      def middleware_stack
        @middleware_stack ||= []
      end

      # Register a middleware.
      #
      # @param klass_or_proc [Class, Proc, #call]
      # @param options [Hash]
      # @option options [Integer] :at insertion position
      # @return [void]
      def register_middleware(klass_or_proc, **options)
        at = options.delete(:at)
        entry = { callable: Callable.wrap(klass_or_proc), options: options }

        if at
          middleware_stack.insert(at, entry)
        else
          middleware_stack << entry
        end

        @middleware_chain = nil
      end

      # Shortcut for register_middleware.
      def middleware(klass_or_proc, **options)
        register_middleware(klass_or_proc, **options)
      end

      # Remove a middleware.
      #
      # @param klass [Class]
      # @return [void]
      def deregister_middleware(klass)
        middleware_stack.reject! do |entry|
          entry[:callable] == klass || entry[:callable].is_a?(klass)
        rescue StandardError
          false
        end
        @middleware_chain = nil
      end

      # Build and cache the middleware execution chain.
      # @api private
      def middleware_chain
        @middleware_chain ||= build_middleware_chain
      end

      private

      def build_middleware_chain
        global_stack = CMDx.configuration.middlewares
        full_stack = global_stack + middleware_stack
        full_stack.reverse
      end

    end

    private

    # Execute the middleware chain around the given block.
    def run_middleware_chain(&core)
      chain = self.class.middleware_chain
      return yield if chain.empty?

      execute_next = chain.reduce(core) do |next_fn, entry|
        callable = entry[:callable]
        options = entry[:options]
        lambda {
          yielded = false
          result = Callable.resolve(callable, self, self, options) do
            yielded = true
            next_fn.call
          end
          self.result.fail!(Messages.resolve("middleware.no_yield")) unless yielded
          result
        }
      end

      execute_next.call
    end

  end
end

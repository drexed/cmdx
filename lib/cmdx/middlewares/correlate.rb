# frozen_string_literal: true

module CMDx
  module Middlewares
    # Adds correlation IDs for distributed tracing.
    # Thread/fiber-safe via the same storage mechanism as Chain.
    class Correlate

      STORAGE_KEY = :cmdx_correlation_id
      private_constant :STORAGE_KEY

      class << self

        # @return [String, nil]
        def id
          if Chain::FIBER_STORAGE
            Fiber[STORAGE_KEY]
          else
            Thread.current[STORAGE_KEY]
          end
        end

        # @param value [String, nil]
        def id=(value)
          if Chain::FIBER_STORAGE
            Fiber[STORAGE_KEY] = value
          else
            Thread.current[STORAGE_KEY] = value
          end
        end

        # Scoped block with a specific correlation ID.
        # Restores the previous ID after the block completes.
        #
        # @param correlation_id [String]
        # @yield
        def use(correlation_id)
          previous = id
          self.id = correlation_id
          yield
        ensure
          self.id = previous
        end

        # Clear the current correlation ID.
        def clear
          self.id = nil
        end

      end

      def call(task, options = {})
        return yield if options.key?(:if) && !Callable.evaluate(options[:if], task)

        return yield if options.key?(:unless) && Callable.evaluate(options[:unless], task)

        correlation_id = resolve_id(task, options)
        self.class.id ||= correlation_id

        result = yield
        result.metadata[:correlation_id] = self.class.id if result
        result
      end

      private

      def resolve_id(task, options)
        value = options[:id]
        case value
        when nil     then self.class.id || generate_uuid
        when String  then value
        when Symbol  then task.send(value)
        when Proc    then value.call(task)
        else
          value.respond_to?(:call) ? value.call(task) : generate_uuid
        end
      end

      def generate_uuid
        Chain::UUID_V7 ? SecureRandom.uuid_v7 : SecureRandom.uuid
      end

    end
  end
end

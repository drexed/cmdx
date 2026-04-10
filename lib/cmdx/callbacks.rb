# frozen_string_literal: true

module CMDx
  # Class-level callback registry with lifecycle hooks.
  # Mixed into Task to provide before/after execution callbacks.
  module Callbacks

    TYPES = %i[
      before_validation before_execution
      on_complete on_interrupted on_executed
      on_success on_skipped on_failed
      on_good on_bad
    ].freeze

    STATUS_MAP = {
      on_complete: ->(_r) { true },
      on_interrupted: ->(_r) { true },
      on_executed: ->(_r) { true },
      on_success: lambda(&:success?),
      on_skipped: lambda(&:skipped?),
      on_failed: lambda(&:failed?),
      on_good: lambda(&:good?),
      on_bad: lambda(&:bad?)
    }.freeze

    STATE_MAP = {
      on_complete: lambda(&:complete?),
      on_interrupted: lambda(&:interrupted?),
      on_executed: lambda(&:executed?)
    }.freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@callbacks, deep_dup_callbacks)
      end

      # @return [Hash<Symbol, Array>]
      def callback_registry
        @callback_registry ||= Hash.new { |h, k| h[k] = [] }
      end

      TYPES.each do |type|
        define_method(type) do |*callables, **conditions|
          callables.each do |cb|
            callback_registry[type] << { callable: Callable.wrap(cb), conditions: conditions }
          end
        end
      end

      # Remove a callback.
      #
      # @param type [Symbol]
      # @param callable_to_remove [Symbol, Class]
      # @return [void]
      def deregister_callback(type, callable_to_remove)
        return unless @callbacks&.key?(type)

        @callbacks[type].reject! do |entry|
          c = entry[:callable]
          c == callable_to_remove ||
            (c.is_a?(Symbol) && c == callable_to_remove) ||
            (callable_to_remove.is_a?(Class) && c.is_a?(callable_to_remove))
        end
      end

      private

      def deep_dup_callbacks
        return Hash.new { |h, k| h[k] = [] } unless instance_variable_defined?(:@callbacks)

        @callbacks.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(type, entries), dup|
          dup[type] = entries.map(&:dup)
        end
      end

    end

    private

    # Run before-type callbacks.
    def run_before_callbacks(type)
      entries = merged_callbacks(type)
      entries.each do |entry|
        next unless conditions_met?(entry[:conditions])

        Callable.resolve(entry[:callable], self)
      end
    end

    # Run after-type callbacks (state/status-based).
    def run_after_callbacks
      run_state_callbacks
      run_status_callbacks
    end

    def run_state_callbacks
      %i[on_complete on_interrupted on_executed].each do |type|
        state_check = Callbacks::STATE_MAP[type]
        next unless state_check&.call(result)

        merged_callbacks(type).each do |entry|
          next unless conditions_met?(entry[:conditions])

          Callable.resolve(entry[:callable], self)
        end
      end
    end

    def run_status_callbacks
      %i[on_success on_skipped on_failed on_good on_bad].each do |type|
        status_check = Callbacks::STATUS_MAP[type]
        next unless status_check&.call(result)

        merged_callbacks(type).each do |entry|
          next unless conditions_met?(entry[:conditions])

          Callable.resolve(entry[:callable], self)
        end
      end
    end

    def merged_callbacks(type)
      global = CMDx.configuration.callbacks[type] || []
      task_level = self.class.callback_registry[type] || []
      global + task_level
    end

    def conditions_met?(conditions)
      return true if conditions.empty?

      return false if conditions.key?(:if) && !Callable.evaluate(conditions[:if], self)

      return false if conditions.key?(:unless) && Callable.evaluate(conditions[:unless], self)

      true
    end

  end
end

# frozen_string_literal: true

module CMDx
  module Callbacks
    class Registry

      TYPES = [
        :before_validation,
        :after_validation,
        :before_execution,
        :after_execution,
        :on_executed,
        :on_good,
        :on_bad,
        *Result::STATUSES.map { |s| :"on_#{s}" },
        *Result::STATES.map { |s| :"on_#{s}" }
      ].freeze

      attr_reader :registry

      def initialize(registry = {})
        @registry = registry
      end

      def register(type, *callables, **options, &block)
        callables << block if block_given?
        (registry[type] ||= []).push([callables, options]).uniq!
        self
      end

      def call(task, type)
        raise UnknownCallbackError, "unknown callback #{type}" unless TYPES.include?(type)

        Array(registry[type]).each do |callables, options|
          next unless task.cmdx_eval(options)

          Array(callables).each do |callable|
            case callable
            when Symbol, String, Proc
              task.cmdx_try(callable)
            else
              callable.call(task)
            end
          end
        end
      end

      def to_h
        registry.transform_values(&:dup)
      end

    end
  end
end

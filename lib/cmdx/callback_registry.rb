# frozen_string_literal: true

module CMDx
  class CallbackRegistry

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

    EVAL = proc do |task, callable, value|
      case callable
      when NilClass, FalseClass, TrueClass then !!callable
      when String, Symbol then task.send(callable, value)
      when Proc then callable.call(value)
      else raise "cannot evaluate #{callable}"
      end
    end.freeze
    private_constant :EVAL

    attr_reader :registry

    def initialize(registry = {})
      @registry = registry
    end

    def dup
      self.class.new(registry.transform_values(&:dup))
    end

    def register(type, *callables, **options, &block)
      callables << block if block_given?

      registry[type] ||= Set.new
      registry[type] << [callables, options]
      self
    end

    def call(type, task)
      raise UnknownCallbackError, "unknown callback #{type}" unless TYPES.include?(type)

      Array(registry[type]).each do |callables, options|
        next unless Utils::Condition.evaluate!(task, options, task)

        Array(callables).each do |callable|
          case callable
          when Symbol, String then task.send(callable, options)
          else callable.call(task, options)
          end
        end
      end
    end

  end
end

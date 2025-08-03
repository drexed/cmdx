# frozen_string_literal: true

module CMDx
  class CallbackRegistry

    TYPES = %i[
      before_validation
      before_execution
      on_complete
      on_interrupted
      on_executed
      on_success
      on_skipped
      on_failed
      on_good
      on_bad
    ].freeze

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

    def invoke!(type, task)
      raise "unknown callback type #{type.inspect}" unless TYPES.include?(type)

      Array(registry[type]).each do |callables, options|
        next unless Utils::Condition.evaluate!(task, options, task)

        Array(callables).each { |callable| Utils::Call.invoke!(task, callable) }
      end
    end

  end
end

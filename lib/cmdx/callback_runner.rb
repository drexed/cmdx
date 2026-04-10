# frozen_string_literal: true

module CMDx
  # Invokes registered callbacks for a given lifecycle phase.
  module CallbackRunner

    # @param phase [Symbol] callback phase (e.g. :before_validation)
    # @param registry [Hash{Symbol => Array}] callback registry
    # @param task [Task] task instance
    # @param result [Result, nil]
    #
    # @rbs (Symbol phase, Hash[Symbol, Array[untyped]] registry, Task task, Result? result) -> void
    def self.run(phase, registry, task, result)
      entries = registry[phase]
      return unless entries&.any?

      entries.each do |entry|
        callable, options = normalize(entry)
        next unless condition_met?(options, task)

        invoke(callable, task, result)
      end
    end

    # @rbs (untyped entry) -> [untyped, Hash[Symbol, untyped]]
    def self.normalize(entry)
      case entry
      when Array then [entry[0], entry[1] || {}]
      when Hash then [entry[:callable], entry.except(:callable)]
      else [entry, {}]
      end
    end

    # @rbs (Hash[Symbol, untyped] options, Task task) -> bool
    def self.condition_met?(options, task)
      return false if options[:if] && !Utils::Condition.evaluate(task, options[:if])

      return false if options[:unless] && Utils::Condition.evaluate(task, options[:unless])

      true
    end

    # @rbs (untyped callable, Task task, Result? result) -> void
    def self.invoke(callable, task, result)
      case callable
      when Symbol
        task.send(callable, *[result].compact)
      when Proc
        if callable.arity.zero?
          task.instance_exec(&callable)
        else
          task.instance_exec(result, &callable)
        end
      else
        callable.call(task, result)
      end
    end

    private_class_method :normalize, :condition_met?, :invoke

  end
end

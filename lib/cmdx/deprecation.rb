# frozen_string_literal: true

module CMDx
  # Declared via `Task.deprecation`. Runs before a task's lifecycle to warn,
  # log, raise, or delegate when a task class has been marked deprecated.
  # Supports conditional `:if` / `:unless` gating via {Util.satisfied?}.
  class Deprecation

    # @param value [:log, :warn, :error, Symbol, Proc, #call, nil] action to take;
    #   `nil` disables
    # @param options [Hash{Symbol => Object}]
    # @option options [Symbol, Proc, #call] :if
    # @option options [Symbol, Proc, #call] :unless
    def initialize(value, options = EMPTY_HASH)
      @value   = value
      @options = options.freeze
    end

    # Runs the configured deprecation action, yielding first so Runtime can
    # mark the result as deprecated for telemetry.
    #
    # @param task [Task]
    # @yield invoked immediately before the action runs, only when conditions pass
    # @return [void]
    # @raise [DeprecationError] when `value` is `:error`
    # @raise [ArgumentError] when `value` is an unsupported type
    def execute(task)
      return if @value.nil?
      return unless Util.satisfied?(@options[:if], @options[:unless], task)

      yield

      case @value
      when :log
        task.logger.warn { "DEPRECATED: #{task.class} - migrate to a replacement or discontinue use" }
      when :warn
        Kernel.warn("[#{task.class}] DEPRECATED: migrate to a replacement or discontinue use")
      when :error
        raise DeprecationError, "#{task.class} usage prohibited"
      when Symbol
        task.send(@value)
      when Proc
        task.instance_exec(task, &@value)
      else
        return @value.call(task) if @value.respond_to?(:call)

        raise ArgumentError, "deprecation must be a Symbol, Proc, or respond to #call"
      end
    end

  end
end

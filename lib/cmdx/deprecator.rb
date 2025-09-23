# frozen_string_literal: true

module CMDx
  # Handles deprecation warnings and restrictions for tasks.
  #
  # The Deprecator module provides functionality to restrict usage of deprecated
  # tasks based on configuration settings. It supports different deprecation
  # behaviors including warnings, logging, and errors.
  module Deprecator

    extend self

    EVAL = proc do |target, callable|
      case callable
      when /raise|log|warn/ then callable
      when NilClass, FalseClass, TrueClass then !!callable
      when Symbol then target.send(callable)
      when Proc then target.instance_eval(&callable)
      else
        raise "cannot evaluate #{callable.inspect}" unless callable.respond_to?(:call)

        callable.call(target)
      end
    end.freeze
    private_constant :EVAL

    # Restricts task usage based on deprecation settings.
    #
    # @param task [Object] The task object to check for deprecation
    # @option task.class.settings[:deprecate] [Symbol, Proc, String, Boolean]
    #   The deprecation configuration for the task
    # @option task.class.settings[:deprecate] :raise Raises DeprecationError
    # @option task.class.settings[:deprecate] :log Logs deprecation warning
    # @option task.class.settings[:deprecate] :warn Outputs warning to stderr
    # @option task.class.settings[:deprecate] true Raises DeprecationError
    # @option task.class.settings[:deprecate] false No action taken
    # @option task.class.settings[:deprecate] nil No action taken
    #
    # @raise [DeprecationError] When deprecation type is :raise or true
    # @raise [RuntimeError] When deprecation type is unknown
    #
    # @example
    #   class MyTask
    #     settings(deprecate: :warn)
    #   end
    #
    #   MyTask.new # => [MyTask] DEPRECATED: migrate to a replacement or discontinue use
    def restrict(task)
      type = EVAL.call(task, task.class.settings[:deprecate])

      case type
      when NilClass, FalseClass # Do nothing
      when TrueClass, /raise/ then raise DeprecationError, "#{task.class.name} usage prohibited"
      when /log/ then task.logger.warn { "DEPRECATED: migrate to a replacement or discontinue use" }
      when /warn/ then warn("[#{task.class.name}] DEPRECATED: migrate to a replacement or discontinue use", category: :deprecated)
      else raise "unknown deprecation type #{type.inspect}"
      end
    end

  end
end

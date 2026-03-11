# frozen_string_literal: true

module CMDx
  # Handles deprecation warnings and restrictions for tasks.
  #
  # The Deprecator module provides functionality to restrict usage of deprecated
  # tasks based on configuration settings. It supports different deprecation
  # behaviors including warnings, logging, and errors.
  module Deprecator

    extend self

    # @rbs RAISE_REGEXP: Regexp
    RAISE_REGEXP = /\Araise\z/
    private_constant :RAISE_REGEXP

    # @rbs LOG_REGEXP: Regexp
    LOG_REGEXP = /\Alog\z/
    private_constant :LOG_REGEXP

    # @rbs WARN_REGEXP: Regexp
    WARN_REGEXP = /\Awarn\z/
    private_constant :WARN_REGEXP

    # @rbs EVAL: Proc
    EVAL = proc do |target, callable|
      case callable
      when NilClass, FalseClass, TrueClass then !!callable
      when RAISE_REGEXP, LOG_REGEXP, WARN_REGEXP then callable
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
    # @option task.class.settings.deprecate [Symbol, Proc, String, Boolean]
    #   The deprecation configuration for the task
    # @option task.class.settings.deprecate :raise Raises DeprecationError
    # @option task.class.settings.deprecate :log Logs deprecation warning
    # @option task.class.settings.deprecate :warn Outputs warning to stderr
    # @option task.class.settings.deprecate true Raises DeprecationError
    # @option task.class.settings.deprecate false No action taken
    # @option task.class.settings.deprecate nil No action taken
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
    #
    # @rbs (Task task) -> void
    def restrict(task)
      setting = task.class.settings.deprecate
      return unless setting

      case type = EVAL.call(task, setting)
      when NilClass, FalseClass then nil # Do nothing
      when TrueClass, RAISE_REGEXP then raise DeprecationError, "#{task.class.name} usage prohibited"
      when LOG_REGEXP then task.logger.warn { "DEPRECATED: migrate to a replacement or discontinue use" }
      when WARN_REGEXP then warn("[#{task.class.name}] DEPRECATED: migrate to a replacement or discontinue use", category: :deprecated)
      else raise "unknown deprecation type #{type.inspect}"
      end
    end

  end
end

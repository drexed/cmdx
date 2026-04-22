# frozen_string_literal: true

module CMDx
  # Per-task configuration overrides. Options are frozen on construction;
  # {#build} returns a new instance rather than mutating. Every getter falls
  # back to {CMDx.configuration} when the option wasn't set on the task.
  class Settings

    # @param options [Hash{Symbol => Object}] task-specific overrides
    # @option options [Logger] :logger
    # @option options [#call] :log_formatter
    # @option options [Integer] :log_level
    # @option options [#call] :backtrace_cleaner
    # @option options [Array<Symbol>] :log_exclusions
    # @option options [Array<Symbol, String>] :tags
    # @option options [Boolean] :strict_context
    def initialize(options = EMPTY_HASH)
      @options = options.freeze
    end

    # Returns a new Settings with `new_options` merged on top. Returns `self`
    # unchanged when `new_options` is empty (used by Task inheritance).
    #
    # @param new_options [Hash{Symbol => Object}] overrides to layer on top
    # @return [Settings] merged instance (or `self` when no changes)
    def build(new_options)
      return self if new_options.empty?

      self.class.new(@options.merge(new_options))
    end

    # @return [Logger] task-level logger or the global configuration's logger
    def logger
      @options.fetch(:logger) do
        CMDx.configuration.logger
      end
    end

    # @return [#call] Logger formatter used when logging task results
    def log_formatter
      @options.fetch(:log_formatter) do
        CMDx.configuration.log_formatter
      end
    end

    # @return [Integer] `Logger` severity level
    def log_level
      @options.fetch(:log_level) do
        CMDx.configuration.log_level
      end
    end

    # @return [#call, nil] callable that cleans fault backtrace frames
    def backtrace_cleaner
      @options.fetch(:backtrace_cleaner) do
        CMDx.configuration.backtrace_cleaner
      end
    end

    # @return [Array<Symbol>] keys to exclude from logging
    def log_exclusions
      @options.fetch(:log_exclusions) do
        CMDx.configuration.log_exclusions
      end
    end

    # Returns a fresh array each call so callers can mutate the result
    # without affecting other tasks (or hitting `FrozenError` on the
    # shared sentinel).
    #
    # @return [Array<Symbol, String>] task tags, surfaced on result hashes
    def tags
      tags = @options[:tags]
      tags ? tags.dup : []
    end

    # @return [Boolean] whether this task's {Context} should raise on
    #   unknown dynamic reads; falls back to
    #   {Configuration#strict_context}
    def strict_context
      @options.fetch(:strict_context) do
        CMDx.configuration.strict_context
      end
    end

  end
end

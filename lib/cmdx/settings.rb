# frozen_string_literal: true

module CMDx
  # Per-task class-level configuration that inherits from parent and
  # falls back to global Configuration. Merges on subsequent calls.
  class Settings

    KEYS = %i[
      task_breakpoints workflow_breakpoints breakpoints
      rollback_on dump_context freeze_results
      backtrace backtrace_cleaner exception_handler logger
      retries retry_on retry_jitter
      tags deprecate
      log_level log_formatter
      returns
    ].freeze

    attr_reader :overrides

    def initialize(parent: nil)
      @parent = parent
      @overrides = {}
    end

    def initialize_copy(source)
      super
      @overrides = source.overrides.dup
    end

    # Merge settings. Last-write-wins per key.
    #
    # @param options [Hash]
    # @return [self]
    def merge!(options)
      options.each do |key, value|
        @overrides[key.to_sym] = value
      end
      self
    end

    # Resolve a setting: task-level -> parent -> global config.
    #
    # @param key [Symbol]
    # @return [Object]
    def [](key)
      sym = key.to_sym
      return @overrides[sym] if @overrides.key?(sym)
      return @parent[sym] if @parent

      config = CMDx.configuration
      config.respond_to?(sym) ? config.public_send(sym) : nil
    end

    # Convenience accessors for common settings.

    def task_breakpoints
      self[:breakpoints] || self[:task_breakpoints]
    end

    def workflow_breakpoints
      self[:breakpoints] || self[:workflow_breakpoints]
    end

    def rollback_on
      self[:rollback_on]
    end

    def retries
      self[:retries] || 0
    end

    def retry_on
      self[:retry_on] || [StandardError]
    end

    def retry_jitter
      self[:retry_jitter] || 0
    end

    def tags
      self[:tags] || []
    end

    def deprecate
      self[:deprecate]
    end

    def log_level
      self[:log_level] || :info
    end

    def log_formatter
      self[:log_formatter]
    end

    def logger
      self[:logger]
    end

    def freeze_results
      val = self[:freeze_results]
      val.nil? || val
    end

    def backtrace
      self[:backtrace] || false
    end

    def backtrace_cleaner
      self[:backtrace_cleaner]
    end

    def exception_handler
      self[:exception_handler]
    end

    def dump_context
      self[:dump_context] || false
    end

    def returns_keys
      self[:returns] || []
    end

  end
end

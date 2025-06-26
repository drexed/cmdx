# frozen_string_literal: true

module CMDx
  ##
  # The HookRegistry collection provides a lifecycle hook system that executes
  # registered hooks at specific points during task execution. Hooks can be
  # conditionally executed based on task state and support both method references
  # and callable objects.
  #
  # The HookRegistry collection extends Hash to provide specialized functionality for
  # managing collections of hook definitions within CMDx tasks. It handles
  # hook registration, conditional execution, and inspection.
  #
  # @example Basic hook usage
  #   hook_registry = HookRegistry.new
  #   hook_registry.register(:before_validation, :check_permissions)
  #   hook_registry.register(:on_success, :log_success, if: :important?)
  #   hook_registry.register(:on_failure, proc { alert_admin }, unless: :test_env?)
  #
  #   hook_registry.call(task, :before_validation)
  #
  # @example Hash-like operations
  #   hook_registry[:before_validation] = [[:check_permissions, {}]]
  #   hook_registry.keys  # => [:before_validation]
  #   hook_registry.empty?  # => false
  #   hook_registry.each { |hook_name, hooks| puts "#{hook_name}: #{hooks}" }
  #
  # @see Hook Base hook execution class
  # @see Task Task lifecycle hooks
  # @since 1.0.0
  class HookRegistry < Hash

    # Registers a hook for the given hook type.
    #
    # @param hook [Symbol] The hook type (e.g., :before_validation, :on_success)
    # @param callables [Array<Symbol, Proc, #call>] Methods or callables to execute
    # @param options [Hash] Conditions for hook execution
    # @option options [Symbol, Proc, #call] :if condition that must be truthy
    # @option options [Symbol, Proc, #call] :unless condition that must be falsy
    # @param block [Proc] Block to execute as part of the hook
    # @return [HookRegistry] self for method chaining
    #
    # @example Register method hook
    #   registry.register(:before_validation, :check_permissions)
    #
    # @example Register conditional hook
    #   registry.register(:on_failure, :alert_admin, if: :critical?)
    #
    # @example Register proc hook
    #   registry.register(:on_success, proc { log_completion })
    def register(hook, *callables, **options, &block)
      callables << block if block_given?
      (self[hook] ||= []).push([callables, options]).uniq!
      self
    end

    # Executes all hooks registered for a specific hook type on the given task.
    # Each hook is evaluated for its conditions (if/unless) before execution.
    #
    # @param task [Task] The task instance to execute hooks on
    # @param hook [Symbol] The hook type to execute (e.g., :before_validation, :on_success)
    # @return [void]
    #
    # @example Execute hooks
    #   registry.call(task, :before_validation)
    #
    # @example Execute conditional hooks
    #   # Only executes if task.critical? returns true
    #   registry.call(task, :on_failure) # where registry has on_failure :alert, if: :critical?
    def call(task, hook)
      return unless key?(hook)

      Array(self[hook]).each do |callables, options|
        next unless task.__cmdx_eval(options)

        Array(callables).each do |h|
          if h.is_a?(Hook)
            h.call(task, hook)
          else
            task.__cmdx_try(h)
          end
        end
      end
    end

  end
end

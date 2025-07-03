# frozen_string_literal: true

module CMDx
  module Testing
    # Hook builder utilities for creating test hook classes
    #
    # This module provides convenient methods for creating CMDx::Hook classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Hook)`
    # patterns, these builders offer semantic shortcuts for common test scenarios.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Hook)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved semantic clarity.
    #
    # @example Manual vs Builder Approach
    #   # Manual approach (explicit, full control)
    #   hook_class = Class.new(CMDx::Hook) do
    #     def self.name
    #       "ValidationHook"
    #     end
    #
    #     def call(task, hook_type)
    #       # Custom hook logic
    #       task.context.validated = true
    #     end
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   hook_class = create_simple_hook(name: "ValidationHook")
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex custom behavior
    #   # - The test scenario is unique or highly specific
    #   # - You want maximum transparency in the test
    #
    #   # Use builder approach when:
    #   # - Testing common hook scenarios
    #   # - You want semantic clarity in test intent
    #   # - You need consistent test patterns across the codebase
    #
    # @since 1.0.0
    module HookBuilders

      # @group Basic Hook Creation

      # Creates a new hook class with optional configuration
      #
      # This is the foundation method for creating CMDx hook classes. It provides
      # a clean interface for creating hook classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param name [String] name for the hook class (defaults to "AnonymousHook")
      # @param block [Proc] optional block to evaluate in hook class context
      # @return [Class] new hook class inheriting from CMDx::Hook
      #
      # @example Basic hook class creation
      #   hook_class = create_hook_class do
      #     def call(task, hook_type)
      #       task.context.hook_executed = true
      #     end
      #   end
      #
      # @example Named hook class with custom behavior
      #   hook_class = create_hook_class(name: "ValidationHook") do
      #     def call(task, hook_type)
      #       case hook_type
      #       when :before
      #         task.context.validation_started = true
      #       when :after
      #         task.context.validation_completed = true
      #       end
      #     end
      #   end
      #
      # @example Hook class with configuration
      #   hook_class = create_hook_class(name: "LoggingHook") do
      #     def call(task, hook_type)
      #       logger = task.logger
      #       logger&.info("Hook #{hook_type} executed for #{task.class.name}")
      #     end
      #   end
      def create_hook_class(name: "AnonymousHook", &block)
        hook_class = Class.new(CMDx::Hook)
        hook_class.define_singleton_method(:name) { name }
        hook_class.class_eval(&block) if block_given?
        hook_class
      end

      # Creates a simple hook that performs basic hook functionality
      #
      # This is the most basic hook type, useful for testing hook execution
      # flow without complex logic. It provides a default call method that
      # can be extended with additional behavior.
      #
      # @param name [String] name for the hook class (defaults to "SimpleHook")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] hook class with basic call method implementation
      #
      # @example Basic usage
      #   hook_class = create_simple_hook
      #   hook_instance = hook_class.new
      #   hook_instance.call(task, :before) # Executes without error
      #
      # @example Named simple hook
      #   hook_class = create_simple_hook(name: "ProcessingHook")
      #   expect(hook_class.name).to eq("ProcessingHook")
      #
      # @example Simple hook with additional behavior
      #   hook_class = create_simple_hook(name: "AuditHook") do
      #     # Override the call method for custom behavior
      #     define_method :call do |task, hook_type|
      #       super(task, hook_type) # Call the default implementation
      #       task.context.audit_log ||= []
      #       task.context.audit_log << "#{hook_type}_hook_executed"
      #     end
      #   end
      #
      # @example Using in RSpec tests
      #   let(:hook_class) { create_simple_hook(name: "TestHook") }
      #
      #   it "executes hook without error" do
      #     hook = hook_class.new
      #     expect { hook.call(task, :before) }.not_to raise_error
      #   end
      def create_simple_hook(name: "SimpleHook", &block)
        create_hook_class(name: name) do
          define_method :call do |task, hook_type|
            # Implementation
          end

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

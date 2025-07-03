# frozen_string_literal: true

module CMDx
  module Testing
    # Callback builder utilities for creating test callback classes
    #
    # This module provides convenient methods for creating CMDx::Callback classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Callback)`
    # patterns, these builders offer semantic shortcuts for common test scenarios.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Callback)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved semantic clarity.
    #
    # @example Manual vs Builder Approach
    #   # Manual approach (explicit, full control)
    #   callback_class = Class.new(CMDx::Callback) do
    #     def self.name
    #       "ValidationCallback"
    #     end
    #
    #     def call(task, callback_type)
    #       # Custom callback logic
    #       task.context.validated = true
    #     end
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   callback_class = create_simple_callback(name: "ValidationCallback")
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex custom behavior
    #   # - The test scenario is unique or highly specific
    #   # - You want maximum transparency in the test
    #
    #   # Use builder approach when:
    #   # - Testing common callback scenarios
    #   # - You want semantic clarity in test intent
    #   # - You need consistent test patterns across the codebase
    #
    # @since 1.0.0
    module CallbackBuilders

      # @group Basic Callback Creation

      # Creates a new callback class with optional configuration
      #
      # This is the foundation method for creating CMDx callback classes. It provides
      # a clean interface for creating callback classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param name [String] name for the callback class (defaults to "AnonymousCallback")
      # @param block [Proc] optional block to evaluate in callback class context
      # @return [Class] new callback class inheriting from CMDx::Callback
      #
      # @example Basic callback class creation
      #   callback_class = create_callback_class do
      #     def call(task, callback_type)
      #       task.context.callback_executed = true
      #     end
      #   end
      #
      # @example Named callback class with custom behavior
      #   callback_class = create_callback_class(name: "ValidationCallback") do
      #     def call(task, callback_type)
      #       case callback_type
      #       when :before
      #         task.context.validation_started = true
      #       when :after
      #         task.context.validation_completed = true
      #       end
      #     end
      #   end
      #
      # @example Callback class with configuration
      #   callback_class = create_callback_class(name: "LoggingCallback") do
      #     def call(task, callback_type)
      #       logger = task.logger
      #       logger&.info("Callback #{callback_type} executed for #{task.class.name}")
      #     end
      #   end
      def create_callback_class(name: "AnonymousCallback", &block)
        callback_class = Class.new(CMDx::Callback)
        callback_class.define_singleton_method(:name) { name }
        callback_class.class_eval(&block) if block_given?
        callback_class
      end

      # Creates a simple callback that performs basic callback functionality
      #
      # This is the most basic callback type, useful for testing callback execution
      # flow without complex logic. It provides a default call method that
      # can be extended with additional behavior.
      #
      # @param name [String] name for the callback class (defaults to "SimpleCallback")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] callback class with basic call method implementation
      #
      # @example Basic usage
      #   callback_class = create_simple_callback
      #   callback_instance = callback_class.new
      #   callback_instance.call(task, :before) # Executes without error
      #
      # @example Named simple callback
      #   callback_class = create_simple_callback(name: "ProcessingCallback")
      #   expect(callback_class.name).to eq("ProcessingCallback")
      #
      # @example Simple callback with additional behavior
      #   callback_class = create_simple_callback(name: "AuditCallback") do
      #     # Override the call method for custom behavior
      #     define_method :call do |task, callback_type|
      #       super(task, callback_type) # Call the default implementation
      #       task.context.audit_log ||= []
      #       task.context.audit_log << "#{callback_type}_callback_executed"
      #     end
      #   end
      #
      # @example Using in RSpec tests
      #   let(:callback_class) { create_simple_callback(name: "TestCallback") }
      #
      #   it "executes callback without error" do
      #     callback = callback_class.new
      #     expect { callback.call(task, :before) }.not_to raise_error
      #   end
      def create_simple_callback(name: "SimpleCallback", &block)
        create_callback_class(name: name) do
          define_method :call do |task, callback_type|
            # Implementation
          end

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

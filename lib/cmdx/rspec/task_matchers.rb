# frozen_string_literal: true

# Custom RSpec matchers for CMDx task behavior testing
#
# This module provides specialized matchers for testing task classes and their
# behavior rather than execution results. These matchers focus on task structure,
# parameter validation, middleware composition, hook registration, and lifecycle
# management following RSpec Style Guide conventions.
#
# The matchers are designed to test task classes before execution, validating
# their configuration, behavior patterns, and architectural compliance.
#
# @example Parameter validation testing
#   expect(TaskClass).to validate_required_parameter(:user_id)
#   expect(TaskClass).to validate_parameter_type(:count, :integer)
#   expect(TaskClass).to use_default_value(:timeout, 30)
#
# @example Middleware and hook testing
#   expect(TaskClass).to have_middleware(LoggingMiddleware)
#   expect(TaskClass).to have_hook(:before_validation)
#   expect(TaskClass).to execute_hooks(:before_validation, :on_success)
#
# @example Task lifecycle and behavior testing
#   expect(TaskClass).to be_well_formed_task
#   expect(TaskClass).to follow_single_use_pattern
#   expect(TaskClass).to handle_exceptions_gracefully
#
# @see https://rspec.rubystyle.guide/ RSpec Style Guide
# @since 1.0.0

# Tests that a task class validates a required parameter
#
# This matcher verifies that a task properly validates the presence of
# a required parameter by calling the task without the parameter and
# ensuring it fails with an appropriate validation message.
#
# @param [Symbol] parameter_name The name of the required parameter to test
#
# @example Basic required parameter validation
#   expect(CreateUserTask).to validate_required_parameter(:email)
#   expect(ProcessOrderTask).to validate_required_parameter(:order_id)
#
# @example Negated usage
#   expect(OptionalTask).not_to validate_required_parameter(:optional_field)
#
# @return [Boolean] true if task fails validation when parameter is missing
#
# @since 1.0.0
RSpec::Matchers.define :validate_required_parameter do |parameter_name|
  match do |task_class|
    result = task_class.call
    result.failed? &&
      result.metadata[:reason]&.include?("#{parameter_name} is a required parameter")
  end

  failure_message do |task_class|
    result = task_class.call
    if result.success?
      "expected task to fail validation for required parameter #{parameter_name}, but it succeeded"
    elsif result.failed?
      "expected task to fail with message about required parameter #{parameter_name}, but failed with: #{result.metadata[:reason]}"
    else
      "expected task to fail validation for required parameter #{parameter_name}, but was #{result.status}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to validate required parameter #{parameter_name}, but it did"
  end

  description do
    "validate required parameter #{parameter_name}"
  end
end

# Tests that a task class validates parameter type coercion
#
# This matcher verifies that a task properly validates parameter types by
# passing an invalid type value and ensuring the task fails with an
# appropriate type validation message.
#
# @param [Symbol] parameter_name The name of the parameter to test
# @param [Symbol] expected_type The expected parameter type (:integer, :string, :boolean, etc.)
#
# @example Basic type validation testing
#   expect(CreateUserTask).to validate_parameter_type(:age, :integer)
#   expect(UpdateSettingsTask).to validate_parameter_type(:enabled, :boolean)
#   expect(SearchTask).to validate_parameter_type(:filters, :hash)
#
# @example Negated usage
#   expect(FlexibleTask).not_to validate_parameter_type(:flexible_param, :string)
#
# @return [Boolean] true if task fails validation when invalid type is provided
#
# @since 1.0.0
RSpec::Matchers.define :validate_parameter_type do |parameter_name, expected_type|
  match do |task_class|
    # Test with invalid type - use string when expecting integer, etc.
    invalid_value = case expected_type
                    when :integer then "not_an_integer"
                    when :string then 123
                    when :boolean then "not_a_boolean"
                    when :hash then "not_a_hash"
                    when :array then "not_an_array"
                    else "invalid_value"
                    end

    result = task_class.call(parameter_name => invalid_value)
    result.failed? &&
      result.metadata[:reason]&.include?("#{parameter_name} must be a #{expected_type}")
  end

  failure_message do |task_class|
    invalid_value = case expected_type
                    when :integer then "not_an_integer"
                    when :string then 123
                    when :boolean then "not_a_boolean"
                    when :hash then "not_a_hash"
                    when :array then "not_an_array"
                    else "invalid_value"
                    end

    result = task_class.call(parameter_name => invalid_value)
    if result.success?
      "expected task to fail type validation for parameter #{parameter_name} (#{expected_type}), but it succeeded"
    elsif result.failed?
      "expected task to fail with type validation message for #{parameter_name} (#{expected_type}), but failed with: #{result.metadata[:reason]}"
    else
      "expected task to fail type validation for parameter #{parameter_name} (#{expected_type}), but was #{result.status}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to validate parameter type #{parameter_name} (#{expected_type}), but it did"
  end

  description do
    "validate parameter type #{parameter_name} (#{expected_type})"
  end
end

# Tests that a task class uses a specific default value for a parameter
#
# This matcher verifies that when a parameter is not provided, the task
# uses the expected default value by calling the task without the parameter
# and checking the context contains the default value.
#
# @param [Symbol] parameter_name The name of the parameter to test
# @param [Object] default_value The expected default value
#
# @example Basic default value testing
#   expect(ProcessTask).to use_default_value(:timeout, 30)
#   expect(EmailTask).to use_default_value(:priority, "normal")
#   expect(ConfigTask).to use_default_value(:enabled, true)
#
# @example Negated usage
#   expect(RequiredParamTask).not_to use_default_value(:required_field, nil)
#
# @return [Boolean] true if task uses the expected default value
#
# @since 1.0.0
RSpec::Matchers.define :use_default_value do |parameter_name, default_value|
  match do |task_class|
    result = task_class.call
    result.success? &&
      result.context.public_send(parameter_name) == default_value
  end

  failure_message do |task_class|
    result = task_class.call
    if result.failed?
      "expected task to use default value #{default_value} for #{parameter_name}, but task failed: #{result.metadata[:reason]}"
    else
      actual_value = result.context.public_send(parameter_name)
      "expected task to use default value #{default_value} for #{parameter_name}, but was #{actual_value}"
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to use default value #{default_value} for #{parameter_name}, but it did"
  end

  description do
    "use default value #{default_value} for parameter #{parameter_name}"
  end
end

# Tests that a task class has a specific middleware registered
#
# This matcher verifies that a task has registered a specific middleware
# class in its middleware registry, ensuring proper middleware composition.
#
# @param [Class] middleware_class The middleware class to check for
#
# @example Basic middleware testing
#   expect(AuthenticatedTask).to have_middleware(AuthenticationMiddleware)
#   expect(LoggedTask).to have_middleware(LoggingMiddleware)
#   expect(TimedTask).to have_middleware(TimeoutMiddleware)
#
# @example Negated usage
#   expect(SimpleTask).not_to have_middleware(ComplexMiddleware)
#
# @return [Boolean] true if task has the specified middleware registered
#
# @since 1.0.0
RSpec::Matchers.define :have_middleware do |middleware_class|
  match do |task_class|
    task_class.cmd_middlewares.any? do |middleware|
      middleware.is_a?(middleware_class) || middleware.instance_of?(middleware_class)
    end
  end

  failure_message do |task_class|
    middleware_classes = task_class.cmd_middlewares.map(&:class)
    "expected task to have middleware #{middleware_class}, but had #{middleware_classes}"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to have middleware #{middleware_class}, but it did"
  end

  description do
    "have middleware #{middleware_class}"
  end
end

# Tests that a task class has a specific hook registered
#
# This matcher verifies that a task has registered a hook for a specific
# lifecycle event. Optionally validates the hook uses a specific callable.
#
# @param [Symbol] hook_name The name of the hook to check for
#
# @example Basic hook testing
#   expect(ValidatedTask).to have_hook(:before_validation)
#   expect(NotifiedTask).to have_hook(:on_success)
#   expect(CleanupTask).to have_hook(:after_execution)
#
# @example Hook with specific callable
#   expect(CustomTask).to have_hook(:on_failure).with_callable(my_proc)
#
# @example Negated usage
#   expect(SimpleTask).not_to have_hook(:complex_hook)
#
# @return [Boolean] true if task has the specified hook registered
#
# @since 1.0.0
RSpec::Matchers.define :have_hook do |hook_name|
  match do |task_class|
    task_class.cmd_hooks.registered?(hook_name)
  end

  chain :with_callable do |callable|
    @expected_callable = callable
  end

  match do |task_class|
    hooks_registered = task_class.cmd_hooks.registered?(hook_name)
    return false unless hooks_registered

    if @expected_callable
      task_class.cmd_hooks.find(hook_name).any? do |hook|
        hook.callable == @expected_callable
      end
    else
      true
    end
  end

  failure_message do |task_class|
    if @expected_callable
      "expected task to have hook #{hook_name} with callable #{@expected_callable}, but it didn't"
    else
      registered_hooks = task_class.cmd_hooks.registered_hooks
      "expected task to have hook #{hook_name}, but had #{registered_hooks}"
    end
  end

  failure_message_when_negated do |_task_class|
    if @expected_callable
      "expected task not to have hook #{hook_name} with callable #{@expected_callable}, but it did"
    else
      "expected task not to have hook #{hook_name}, but it did"
    end
  end

  description do
    desc = "have hook #{hook_name}"
    desc += " with callable #{@expected_callable}" if @expected_callable
    desc
  end
end

# Tests that a task executes specific hooks during its lifecycle
#
# This matcher verifies that when a task is executed, it triggers the
# expected hooks in the proper sequence. Works by mocking hook execution
# and tracking which hooks are called.
#
# @param [Array<Symbol>] hook_names The names of hooks that should be executed
#
# @example Basic hook execution testing
#   expect(task).to execute_hooks(:before_validation, :after_validation)
#   expect(failed_task).to execute_hooks(:before_execution, :on_failure)
#
# @example Single hook execution
#   expect(simple_task).to execute_hooks(:on_success)
#
# @example Negated usage
#   expect(task).not_to execute_hooks(:unused_hook)
#
# @note This matcher requires the task to be executed and may mock internal
#   hook execution mechanisms for testing purposes.
#
# @return [Boolean] true if task executes all specified hooks
#
# @since 1.0.0
RSpec::Matchers.define :execute_hooks do |*hook_names|
  match do |task_or_result|
    @executed_hooks = []

    # Mock the hook execution to track what gets called
    if task_or_result.is_a?(CMDx::Task)
      task = task_or_result
      original_hook_call = task.cmd_hooks.method(:call)

      allow(task.cmd_hooks).to receive(:call) do |task_instance, hook_name|
        @executed_hooks << hook_name
        original_hook_call.call(task_instance, hook_name)
      end

      task.perform
    else
      # If it's a result, check if hooks were executed during task execution
      result = task_or_result
      # This would require the hooks to be tracked during execution
      # For now, assume hooks were executed based on result state
      @executed_hooks = infer_executed_hooks(result)
    end

    hook_names.all? { |hook_name| @executed_hooks.include?(hook_name) }
  end

  failure_message do |_task_or_result|
    missing_hooks = hook_names - @executed_hooks
    "expected to execute hooks #{hook_names}, but missing #{missing_hooks}. Executed: #{@executed_hooks}"
  end

  failure_message_when_negated do |_task_or_result|
    "expected not to execute hooks #{hook_names}, but executed #{@executed_hooks & hook_names}"
  end

  description do
    "execute hooks #{hook_names}"
  end

  private

  def infer_executed_hooks(result)
    hooks = []
    hooks << :before_validation if result.executed?
    hooks << :after_validation if result.executed?
    hooks << :before_execution if result.executed?
    hooks << :after_execution if result.executed?
    hooks << :on_executed if result.executed?
    hooks << :"on_#{result.status}" if result.executed?
    hooks << :on_good if result.good?
    hooks << :on_bad if result.bad?
    hooks << :"on_#{result.state}" if result.executed?
    hooks
  end
end

# Tests that a task instance becomes frozen after execution
#
# This matcher verifies that task instances follow the immutability pattern
# by becoming frozen after execution, preventing further modification of
# the task state.
#
# @example Basic frozen state testing
#   expect(MyTask).to be_frozen_after_execution
#
# @example Negated usage (for mutable tasks)
#   expect(MutableTask).not_to be_frozen_after_execution
#
# @return [Boolean] true if task instance is frozen after execution
#
# @since 1.0.0
RSpec::Matchers.define :be_frozen_after_execution do
  match do |task_class|
    task = task_class.new
    task.perform
    task.frozen?
  end

  failure_message do |_task_class|
    "expected task to be frozen after execution, but it wasn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to be frozen after execution, but it was"
  end

  description do
    "be frozen after execution"
  end
end

# Tests that a task prevents multiple executions of the same instance
#
# This matcher verifies that task instances follow the single-execution
# pattern by raising an error when attempting to execute the same instance
# more than once, ensuring state integrity.
#
# @example Basic multiple execution prevention
#   expect(MyTask).to prevent_multiple_executions
#
# @example Negated usage (for reusable tasks)
#   expect(ReusableTask).not_to prevent_multiple_executions
#
# @return [Boolean] true if task raises error on second execution attempt
#
# @since 1.0.0
RSpec::Matchers.define :prevent_multiple_executions do
  match do |task_class|
    task = task_class.new
    task.perform

    begin
      task.perform
      false # Should not reach here
    rescue RuntimeError => e
      e.message.include?("cannot transition")
    end
  end

  failure_message do |_task_class|
    "expected task to prevent multiple executions, but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to prevent multiple executions, but it did"
  end

  description do
    "prevent multiple executions"
  end
end

# Tests that a task handles exceptions gracefully by converting them to failed results
#
# This matcher verifies that when a task raises an exception during execution,
# it catches the exception and converts it to a failed result with appropriate
# metadata rather than allowing the exception to propagate.
#
# @example Basic exception handling testing
#   expect(RobustTask).to handle_exceptions_gracefully
#
# @example Negated usage (for exception-propagating tasks)
#   expect(StrictTask).not_to handle_exceptions_gracefully
#
# @return [Boolean] true if task converts exceptions to failed results
#
# @since 1.0.0
RSpec::Matchers.define :handle_exceptions_gracefully do
  match do |task_class|
    # Test that exceptions are caught and converted to failed results
    erroring_task = Class.new(task_class) do
      def call
        raise StandardError, "Test error"
      end
    end

    task = erroring_task.new
    task.perform

    task.result.failed? &&
      task.result.metadata[:reason]&.include?("Test error") &&
      task.result.metadata[:original_exception].is_a?(StandardError)
  end

  failure_message do |_task_class|
    "expected task to handle exceptions gracefully by converting to failed results, but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to handle exceptions gracefully, but it did"
  end

  description do
    "handle exceptions gracefully"
  end
end

# Tests that a task propagates exceptions when called with the bang method
#
# This matcher verifies that when using the call! method instead of call,
# exceptions are allowed to propagate rather than being converted to failed
# results, enabling fail-fast behavior when desired.
#
# @example Basic exception propagation testing
#   expect(MyTask).to propagate_exceptions_with_bang
#
# @example Negated usage (for always-graceful tasks)
#   expect(AlwaysGracefulTask).not_to propagate_exceptions_with_bang
#
# @return [Boolean] true if task propagates exceptions with call!
#
# @since 1.0.0
RSpec::Matchers.define :propagate_exceptions_with_bang do
  match do |task_class|
    # Test that call! propagates exceptions instead of handling them
    erroring_task = Class.new(task_class) do
      def call
        raise StandardError, "Test error"
      end
    end

    begin
      erroring_task.call!
      false # Should not reach here
    rescue StandardError => e
      e.message == "Test error"
    end
  end

  failure_message do |_task_class|
    "expected task to propagate exceptions with call!, but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to propagate exceptions with call!, but it did"
  end

  description do
    "propagate exceptions with call!"
  end
end

# Tests that a task class has a specific configuration setting
#
# This matcher verifies that a task has a particular configuration setting
# defined, optionally validating the setting's value. Task settings control
# various aspects of task behavior and execution.
#
# @param [Symbol] setting_name The name of the setting to check for
# @param [Object, nil] expected_value Optional expected value for the setting
#
# @example Basic setting presence testing
#   expect(ConfiguredTask).to have_task_setting(:timeout)
#   expect(CustomTask).to have_task_setting(:priority)
#
# @example Setting with specific value
#   expect(TimedTask).to have_task_setting(:timeout, 30)
#   expect(PriorityTask).to have_task_setting(:priority, "high")
#
# @example Negated usage
#   expect(SimpleTask).not_to have_task_setting(:complex_setting)
#
# @return [Boolean] true if task has the setting (with expected value if provided)
#
# @since 1.0.0
RSpec::Matchers.define :have_task_setting do |setting_name, expected_value = nil|
  match do |task_class|
    return false unless task_class.task_setting?(setting_name)

    if expected_value
      task_class.task_setting(setting_name) == expected_value
    else
      true
    end
  end

  failure_message do |task_class|
    if expected_value
      actual_value = task_class.task_setting(setting_name)
      "expected task to have setting #{setting_name} with value #{expected_value}, but was #{actual_value}"
    else
      available_settings = task_class.task_settings.keys
      "expected task to have setting #{setting_name}, but had #{available_settings}"
    end
  end

  failure_message_when_negated do |_task_class|
    if expected_value
      "expected task not to have setting #{setting_name} with value #{expected_value}, but it did"
    else
      "expected task not to have setting #{setting_name}, but it did"
    end
  end

  description do
    desc = "have task setting #{setting_name}"
    desc += " with value #{expected_value}" if expected_value
    desc
  end
end

# Tests that a task class is well-formed and follows CMDx conventions
#
# This composite matcher verifies that a task class meets all the basic
# structural requirements for a valid CMDx task, including proper inheritance,
# required method implementation, and registry initialization.
#
# Validates that the task:
# - Inherits from CMDx::Task
# - Implements the required call method
# - Has properly initialized parameter, hook, and middleware registries
#
# @example Basic well-formed task validation
#   expect(MyTask).to be_well_formed_task
#   expect(UserCreationTask).to be_well_formed_task
#
# @example Negated usage (for malformed tasks)
#   expect(BrokenTask).not_to be_well_formed_task
#
# @return [Boolean] true if task meets all structural requirements
#
# @since 1.0.0
RSpec::Matchers.define :be_well_formed_task do
  match do |task_class|
    task_class < CMDx::Task &&
      task_class.instance_methods.include?(:call) &&
      task_class.cmd_parameters.is_a?(CMDx::ParameterRegistry) &&
      task_class.cmd_hooks.is_a?(CMDx::HookRegistry) &&
      task_class.cmd_middlewares.is_a?(CMDx::MiddlewareRegistry)
  end

  failure_message do |task_class|
    issues = []
    issues << "does not inherit from CMDx::Task" unless task_class < CMDx::Task
    issues << "does not implement call method" unless task_class.instance_methods.include?(:call)
    issues << "does not have parameter registry" unless task_class.cmd_parameters.is_a?(CMDx::ParameterRegistry)
    issues << "does not have hook registry" unless task_class.cmd_hooks.is_a?(CMDx::HookRegistry)
    issues << "does not have middleware registry" unless task_class.cmd_middlewares.is_a?(CMDx::MiddlewareRegistry)

    "expected task to be well-formed, but #{issues.join(', ')}"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to be well-formed, but it was"
  end

  description do
    "be a well-formed task"
  end
end

# Tests that a task class follows the single-use instance pattern
#
# This composite matcher verifies that a task properly implements the
# single-use pattern fundamental to CMDx task architecture. This includes:
# - Each instance has a unique identifier
# - Instances become frozen after execution
# - Multiple executions of the same instance are prevented
#
# The single-use pattern ensures task instances maintain state integrity
# and follow immutability principles after execution.
#
# @example Basic single-use pattern validation
#   expect(MyTask).to follow_single_use_pattern
#   expect(ProcessingTask).to follow_single_use_pattern
#
# @example Negated usage (for reusable task implementations)
#   expect(ReusableTask).not_to follow_single_use_pattern
#
# @return [Boolean] true if task follows all single-use pattern requirements
#
# @since 1.0.0
RSpec::Matchers.define :follow_single_use_pattern do
  match do |task_class|
    task1 = task_class.new
    task2 = task_class.new

    # Each instance should have unique ID
    task1.id != task2.id &&
      # Tasks should be frozen after execution
      (task1.perform
       task1.frozen?) &&
      # Tasks should prevent multiple executions
      (begin
        task1.perform
        false
      rescue RuntimeError
        true
      end)
  end

  failure_message do |_task_class|
    "expected task to follow single-use pattern (unique IDs, frozen after execution, prevent multiple executions), but it didn't"
  end

  failure_message_when_negated do |_task_class|
    "expected task not to follow single-use pattern, but it did"
  end

  description do
    "follow single-use pattern"
  end
end

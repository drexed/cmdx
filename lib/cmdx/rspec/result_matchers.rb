# frozen_string_literal: true

# Custom RSpec matchers for CMDx result testing
#
# This module provides a comprehensive set of custom RSpec matchers specifically
# designed for testing CMDx task execution results. These matchers follow the
# RSpec Style Guide conventions and provide expressive, readable test assertions
# for task outcomes, side effects, and execution state.
#
# The matchers are automatically loaded when the spec_helper is required and are
# available in all RSpec test contexts.
#
# @example Basic result outcome testing
#   expect(result).to be_successful_task
#   expect(result).to be_failed_task.with_reason("Validation failed")
#   expect(result).to be_skipped_task("Already processed")
#
# @example Side effects and context testing
#   expect(result).to have_context(user_id: 123, processed: true)
#   expect(result).to preserve_context(original_data)
#
# @example Composable matcher usage
#   expect(result).to be_successful_task(user_id: 123)
#     .and have_context(processed_at: be_a(Time))
#     .and have_runtime(be > 0)
#
# @see https://rspec.rubystyle.guide/ RSpec Style Guide
# @since 1.0.0

# Tests that a task result represents a successful execution
#
# This matcher verifies that a result has a success status, complete state,
# and was executed. Optionally validates specific context attributes.
#
# @param [Hash] expected_context Optional hash of context attributes to validate
#
# @example Basic successful task validation
#   expect(result).to be_successful_task
#
# @example Successful task with context validation
#   expect(result).to be_successful_task(user_id: 123, processed: true)
#
# @example Negated usage
#   expect(result).not_to be_successful_task
#
# @return [Boolean] true if result is successful, complete, and executed
#
# @since 1.0.0
RSpec::Matchers.define :be_successful_task do |expected_context = {}|
  match do |result|
    result.success? &&
      result.complete? &&
      result.executed? &&
      (expected_context.empty? || context_matches?(result, expected_context))
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be successful, but was #{result.status}" unless result.success?
    messages << "expected result to be complete, but was #{result.state}" unless result.complete?
    messages << "expected result to be executed, but was not" unless result.executed?

    unless expected_context.empty?
      mismatches = context_mismatches(result, expected_context)
      messages << "expected context to match #{expected_context}, but #{mismatches}" if mismatches.any?
    end

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to be successful, but it was"
  end

  description do
    desc = "be a successful task"
    desc += " with context #{expected_context}" unless expected_context.empty?
    desc
  end

  private

  def context_matches?(result, expected_context)
    expected_context.all? do |key, value|
      result.context.public_send(key) == value
    end
  end

  def context_mismatches(result, expected_context)
    expected_context.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      "#{key}: expected #{expected_value}, got #{actual_value}" if actual_value != expected_value
    end
  end
end

# Tests that a task result represents a failed execution
#
# This matcher verifies that a result has a failed status, interrupted state,
# and was executed. Supports optional reason validation and chainable metadata checks.
#
# @param [String, nil] expected_reason Optional failure reason to validate
#
# @example Basic failed task validation
#   expect(result).to be_failed_task
#
# @example Failed task with specific reason
#   expect(result).to be_failed_task("Validation failed")
#
# @example Chainable reason and metadata validation
#   expect(result).to be_failed_task
#     .with_reason("Invalid data")
#     .with_metadata(error_code: "ERR001", retryable: false)
#
# @example Negated usage
#   expect(result).not_to be_failed_task
#
# @return [Boolean] true if result is failed, interrupted, and executed
#
# @since 1.0.0
RSpec::Matchers.define :be_failed_task do |expected_reason = nil|
  match do |result|
    result.failed? &&
      result.interrupted? &&
      result.executed? &&
      (expected_reason.nil? || result.metadata[:reason] == expected_reason)
  end

  chain :with_reason do |reason|
    @expected_reason = reason
  end

  chain :with_metadata do |metadata|
    @expected_metadata = metadata
  end

  match do |result|
    reason = @expected_reason || expected_reason
    metadata = @expected_metadata || {}

    result.failed? &&
      result.interrupted? &&
      result.executed? &&
      (reason.nil? || result.metadata[:reason] == reason) &&
      (metadata.empty? || metadata.all? { |k, v| result.metadata[k] == v })
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be failed, but was #{result.status}" unless result.failed?
    messages << "expected result to be interrupted, but was #{result.state}" unless result.interrupted?
    messages << "expected result to be executed, but was not" unless result.executed?

    reason = @expected_reason || expected_reason
    messages << "expected failure reason to be '#{reason}', but was '#{result.metadata[:reason]}'" if reason && result.metadata[:reason] != reason

    if @expected_metadata&.any?
      mismatches = @expected_metadata.filter_map do |k, v|
        "#{k}: expected #{v}, got #{result.metadata[k]}" if result.metadata[k] != v
      end
      messages.concat(mismatches)
    end

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to be failed, but it was"
  end

  description do
    desc = "be a failed task"
    reason = @expected_reason || expected_reason
    desc += " with reason '#{reason}'" if reason
    desc += " with metadata #{@expected_metadata}" if @expected_metadata&.any?
    desc
  end
end

# Tests that a task result represents a skipped execution
#
# This matcher verifies that a result has a skipped status, interrupted state,
# and was executed. Supports optional reason validation and chainable metadata checks.
#
# @param [String, nil] expected_reason Optional skip reason to validate
#
# @example Basic skipped task validation
#   expect(result).to be_skipped_task
#
# @example Skipped task with specific reason
#   expect(result).to be_skipped_task("Already processed")
#
# @example Chainable reason and metadata validation
#   expect(result).to be_skipped_task
#     .with_reason("Order already processed")
#     .with_metadata(processed_at: be_a(Time), skip_code: "DUPLICATE")
#
# @example Negated usage
#   expect(result).not_to be_skipped_task
#
# @return [Boolean] true if result is skipped, interrupted, and executed
#
# @since 1.0.0
RSpec::Matchers.define :be_skipped_task do |expected_reason = nil|
  match do |result|
    result.skipped? &&
      result.interrupted? &&
      result.executed? &&
      (expected_reason.nil? || result.metadata[:reason] == expected_reason)
  end

  chain :with_reason do |reason|
    @expected_reason = reason
  end

  chain :with_metadata do |metadata|
    @expected_metadata = metadata
  end

  match do |result|
    reason = @expected_reason || expected_reason
    metadata = @expected_metadata || {}

    result.skipped? &&
      result.interrupted? &&
      result.executed? &&
      (reason.nil? || result.metadata[:reason] == reason) &&
      (metadata.empty? || metadata.all? { |k, v| result.metadata[k] == v })
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be skipped, but was #{result.status}" unless result.skipped?
    messages << "expected result to be interrupted, but was #{result.state}" unless result.interrupted?
    messages << "expected result to be executed, but was not" unless result.executed?

    reason = @expected_reason || expected_reason
    messages << "expected skip reason to be '#{reason}', but was '#{result.metadata[:reason]}'" if reason && result.metadata[:reason] != reason

    if @expected_metadata&.any?
      mismatches = @expected_metadata.filter_map do |k, v|
        "#{k}: expected #{v}, got #{result.metadata[k]}" if result.metadata[k] != v
      end
      messages.concat(mismatches)
    end

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to be skipped, but it was"
  end

  description do
    desc = "be a skipped task"
    reason = @expected_reason || expected_reason
    desc += " with reason '#{reason}'" if reason
    desc += " with metadata #{@expected_metadata}" if @expected_metadata&.any?
    desc
  end
end

# Tests that a task result has a good outcome (success or skipped)
#
# This matcher verifies that a result has either a success or skipped status,
# representing a positive outcome where the task completed its intended purpose
# or was appropriately bypassed.
#
# @example Basic good outcome validation
#   expect(result).to have_good_outcome
#
# @example Negated usage
#   expect(result).not_to have_good_outcome
#
# @return [Boolean] true if result is success or skipped
#
# @since 1.0.0
RSpec::Matchers.define :have_good_outcome do
  match(&:good?)

  failure_message do |result|
    "expected result to have good outcome (success or skipped), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have good outcome, but it did (status: #{result.status})"
  end

  description do
    "have good outcome"
  end
end

# Tests that a task result has a bad outcome (not success)
#
# This matcher verifies that a result does not have a success status,
# representing a negative outcome where the task did not complete successfully.
#
# @example Basic bad outcome validation
#   expect(result).to have_bad_outcome
#
# @example Negated usage
#   expect(result).not_to have_bad_outcome
#
# @return [Boolean] true if result is not success
#
# @since 1.0.0
RSpec::Matchers.define :have_bad_outcome do
  match(&:bad?)

  failure_message do |result|
    "expected result to have bad outcome (not success), but was #{result.status}"
  end

  failure_message_when_negated do |result|
    "expected result not to have bad outcome, but it did (status: #{result.status})"
  end

  description do
    "have bad outcome"
  end
end

# Tests that a task result indicates the task was executed
#
# This matcher verifies that a result shows the task has moved beyond
# the initialized state and has been processed by the execution engine.
#
# @example Basic execution validation
#   expect(result).to be_executed
#
# @example Negated usage
#   expect(result).not_to be_executed
#
# @return [Boolean] true if result indicates execution occurred
#
# @since 1.0.0
RSpec::Matchers.define :be_executed do
  match(&:executed?)

  failure_message do |result|
    "expected result to be executed, but was in #{result.state} state"
  end

  failure_message_when_negated do |result|
    "expected result not to be executed, but it was (state: #{result.state})"
  end

  description do
    "be executed"
  end
end

# Tests that a task result has runtime information
#
# This matcher verifies that a result contains execution timing data.
# Optionally validates the runtime against a specific value or matcher.
#
# @param [Numeric, RSpec::Matchers::BuiltIn::BaseMatcher, nil] expected_runtime
#   Optional runtime value or matcher to validate against
#
# @example Basic runtime presence validation
#   expect(result).to have_runtime
#
# @example Runtime with specific value
#   expect(result).to have_runtime(0.5)
#
# @example Runtime with matcher
#   expect(result).to have_runtime(be > 0)
#   expect(result).to have_runtime(be_within(0.1).of(0.5))
#
# @example Negated usage
#   expect(result).not_to have_runtime
#
# @return [Boolean] true if result has runtime (and matches expectation if provided)
#
# @since 1.0.0
RSpec::Matchers.define :have_runtime do |expected_runtime = nil|
  match do |result|
    return false if result.runtime.nil?
    return true if expected_runtime.nil?

    if expected_runtime.respond_to?(:matches?)
      expected_runtime.matches?(result.runtime)
    else
      result.runtime == expected_runtime
    end
  end

  failure_message do |result|
    if result.runtime.nil?
      "expected result to have runtime, but it was nil"
    elsif expected_runtime
      "expected result runtime to #{expected_runtime}, but was #{result.runtime}"
    end
  end

  failure_message_when_negated do |result|
    if expected_runtime
      "expected result runtime not to #{expected_runtime}, but it was #{result.runtime}"
    else
      "expected result not to have runtime, but it was #{result.runtime}"
    end
  end

  description do
    if expected_runtime
      "have runtime #{expected_runtime}"
    else
      "have runtime"
    end
  end
end

# Tests that a task result contains specific metadata
#
# This matcher verifies that a result's metadata hash contains the expected
# key-value pairs. Supports chainable inclusion for complex metadata validation.
#
# @param [Hash] expected_metadata Hash of metadata keys and values to validate
#
# @example Basic metadata validation
#   expect(result).to have_metadata(reason: "Error", code: "001")
#
# @example Chainable metadata inclusion
#   expect(result).to have_metadata(reason: "Error")
#     .including(code: "001", retryable: false)
#
# @example Empty metadata validation
#   expect(result).to have_metadata({})
#
# @example Negated usage
#   expect(result).not_to have_metadata(reason: "Different error")
#
# @return [Boolean] true if result metadata contains all expected key-value pairs
#
# @since 1.0.0
RSpec::Matchers.define :have_metadata do |expected_metadata = {}|
  match do |result|
    expected_metadata.all? do |key, value|
      actual_value = result.metadata[key]
      if value.respond_to?(:matches?)
        value.matches?(actual_value)
      else
        actual_value == value
      end
    end
  end

  chain :including do |metadata|
    @additional_metadata = metadata
  end

  match do |result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    all_metadata.all? do |key, value|
      actual_value = result.metadata[key]
      if value.respond_to?(:matches?)
        value.matches?(actual_value)
      else
        actual_value == value
      end
    end
  end

  failure_message do |result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    mismatches = all_metadata.filter_map do |key, expected_value|
      actual_value = result.metadata[key]
      match_result = if expected_value.respond_to?(:matches?)
                       expected_value.matches?(actual_value)
                     else
                       actual_value == expected_value
                     end
      "#{key}: expected #{expected_value}, got #{actual_value}" unless match_result
    end
    "expected metadata to include #{all_metadata}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    "expected metadata not to include #{all_metadata}, but it did"
  end

  description do
    all_metadata = expected_metadata.merge(@additional_metadata || {})
    "have metadata #{all_metadata}"
  end
end

# Tests that a task result has no metadata
#
# This matcher verifies that a result's metadata hash is empty,
# indicating no additional execution information was recorded.
#
# @example Basic empty metadata validation
#   expect(result).to have_empty_metadata
#
# @example Negated usage
#   expect(result).not_to have_empty_metadata
#
# @return [Boolean] true if result metadata is empty
#
# @since 1.0.0
RSpec::Matchers.define :have_empty_metadata do
  match do |result|
    result.metadata.empty?
  end

  failure_message do |result|
    "expected metadata to be empty, but was #{result.metadata}"
  end

  failure_message_when_negated do |_result|
    "expected metadata not to be empty, but it was"
  end

  description do
    "have empty metadata"
  end
end

# Tests that a task result has specific side effects in the context
#
# This matcher verifies that the result's context contains expected
# attribute changes or additions that represent the task's side effects.
# Supports both exact value matching and RSpec matcher integration.
#
# @param [Hash] expected_effects Hash of context attributes and expected values
#
# @example Basic side effects validation
#   expect(result).to have_context(processed: true, user_id: 123)
#
# @example Side effects with RSpec matchers
#   expect(result).to have_context(
#     processed_at: be_a(Time),
#     errors: be_empty,
#     count: be > 0
#   )
#
# @example Complex side effects validation
#   expect(result).to have_context(
#     user: have_attributes(id: 123, name: "John"),
#     notifications: contain_exactly("email", "sms")
#   )
#
# @example Negated usage
#   expect(result).not_to have_context(deleted: true)
#
# @return [Boolean] true if context contains all expected side effects
#
# @since 1.0.0
RSpec::Matchers.define :have_context do |expected_effects|
  match do |result|
    expected_effects.all? do |key, expected_value|
      actual_value = result.context.public_send(key)
      if expected_value.respond_to?(:matches?)
        expected_value.matches?(actual_value)
      else
        actual_value == expected_value
      end
    end
  end

  failure_message do |result|
    mismatches = expected_effects.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      match_result = if expected_value.respond_to?(:matches?)
                       expected_value.matches?(actual_value)
                     else
                       actual_value == expected_value
                     end

      "#{key}: expected #{expected_value}, got #{actual_value}" unless match_result
    end
    "expected context to have side effects #{expected_effects}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    "expected context not to have side effects #{expected_effects}, but it did"
  end

  description do
    "have side effects #{expected_effects}"
  end
end

# Tests that a task result preserves specific context attributes
#
# This matcher verifies that certain context attributes retain their
# original values after task execution, ensuring data integrity for
# attributes that should not be modified.
#
# @param [Hash] preserved_attributes Hash of attributes and their expected preserved values
#
# @example Basic context preservation validation
#   expect(result).to preserve_context(user_id: 123, session_id: "abc")
#
# @example Preserving complex data structures
#   expect(result).to preserve_context(
#     original_request: original_data,
#     user_permissions: ["read", "write"]
#   )
#
# @example Negated usage
#   expect(result).not_to preserve_context(temporary_flag: true)
#
# @return [Boolean] true if context preserves all specified attributes
#
# @since 1.0.0
RSpec::Matchers.define :preserve_context do |preserved_attributes|
  match do |result|
    preserved_attributes.all? do |key, expected_value|
      result.context.public_send(key) == expected_value
    end
  end

  failure_message do |result|
    mismatches = preserved_attributes.filter_map do |key, expected_value|
      actual_value = result.context.public_send(key)
      "#{key}: expected #{expected_value}, got #{actual_value}" if actual_value != expected_value
    end
    "expected context to preserve #{preserved_attributes}, but #{mismatches.join(', ')}"
  end

  failure_message_when_negated do |_result|
    "expected context not to preserve #{preserved_attributes}, but it did"
  end

  description do
    "preserve context #{preserved_attributes}"
  end
end

# Tests that a task result represents a failure that was caused (not thrown)
#
# This matcher verifies that a failed result originated from the current task
# rather than being propagated from another task. Used to distinguish between
# original failures and failure propagation in task chains.
#
# @example Basic caused failure validation
#   expect(result).to have_caused_failure
#
# @example Negated usage (for thrown failures)
#   expect(result).not_to have_caused_failure
#
# @return [Boolean] true if result failed and caused the failure
#
# @since 1.0.0
RSpec::Matchers.define :have_caused_failure do
  match do |result|
    result.failed? && result.caused_failure?
  end

  failure_message do |result|
    if result.failed?
      "expected result to have caused failure, but it threw/received a failure instead"
    else
      "expected result to have caused failure, but it was not failed (status: #{result.status})"
    end
  end

  failure_message_when_negated do |_result|
    "expected result not to have caused failure, but it did"
  end

  description do
    "have caused failure"
  end
end

# Tests that a task result represents a failure that was thrown from another task
#
# This matcher verifies that a failed result was propagated from another task
# using CMDx's failure throwing mechanism. Optionally validates the original
# result that was thrown.
#
# @param [CMDx::Result, nil] expected_original_result
#   Optional original result that should have been thrown
#
# @example Basic thrown failure validation
#   expect(result).to have_thrown_failure
#
# @example Thrown failure with specific original result
#   expect(result).to have_thrown_failure(original_failed_result)
#
# @example Negated usage (for caused failures)
#   expect(result).not_to have_thrown_failure
#
# @return [Boolean] true if result failed and threw a failure from another task
#
# @since 1.0.0
RSpec::Matchers.define :have_thrown_failure do |expected_original_result = nil|
  match do |result|
    result.failed? &&
      result.threw_failure? &&
      (expected_original_result.nil? || result.threw_failure == expected_original_result)
  end

  failure_message do |result|
    messages = []
    messages << "expected result to be failed, but was #{result.status}" unless result.failed?
    messages << "expected result to have thrown failure, but it #{result.caused_failure? ? 'caused' : 'received'} failure instead" unless result.threw_failure?

    messages << "expected to throw failure from #{expected_original_result}, but threw from #{result.threw_failure}" if expected_original_result && result.threw_failure != expected_original_result

    messages.join(", ")
  end

  failure_message_when_negated do |_result|
    "expected result not to have thrown failure, but it did"
  end

  description do
    desc = "have thrown failure"
    desc += " from #{expected_original_result}" if expected_original_result
    desc
  end
end

# Tests that a task result represents a failure that was received from a thrown failure
#
# This matcher verifies that a failed result received a failure that was thrown
# from another task in the execution chain. This is the receiving side of the
# failure propagation mechanism.
#
# @example Basic received thrown failure validation
#   expect(result).to have_received_thrown_failure
#
# @example Negated usage
#   expect(result).not_to have_received_thrown_failure
#
# @return [Boolean] true if result failed and received a thrown failure
#
# @since 1.0.0
RSpec::Matchers.define :have_received_thrown_failure do
  match do |result|
    result.failed? && result.thrown_failure?
  end

  failure_message do |result|
    if result.failed?
      "expected result to have received thrown failure, but it #{result.caused_failure? ? 'caused' : 'threw'} failure instead"
    else
      "expected result to have received thrown failure, but it was not failed (status: #{result.status})"
    end
  end

  failure_message_when_negated do |_result|
    "expected result not to have received thrown failure, but it did"
  end

  description do
    "have received thrown failure"
  end
end

# Tests that a task result belongs to a specific chain
#
# This matcher verifies that a result is associated with a CMDx::Chain
# instance, optionally validating it's a specific chain object.
#
# @param [CMDx::Chain, nil] expected_chain
#   Optional specific chain instance to validate against
#
# @example Basic chain membership validation
#   expect(result).to belong_to_chain
#
# @example Specific chain validation
#   expect(result).to belong_to_chain(my_chain)
#
# @example Negated usage
#   expect(result).not_to belong_to_chain
#
# @return [Boolean] true if result belongs to a chain (optionally specific one)
#
# @since 1.0.0
RSpec::Matchers.define :belong_to_chain do |expected_chain = nil|
  match do |result|
    result.chain.is_a?(CMDx::Chain) &&
      (expected_chain.nil? || result.chain == expected_chain)
  end

  failure_message do |result|
    if result.chain.is_a?(CMDx::Chain)
      "expected result to belong to chain #{expected_chain}, but belonged to #{result.chain}"
    else
      "expected result to belong to a chain, but chain was #{result.chain.class}"
    end
  end

  failure_message_when_negated do |_result|
    if expected_chain
      "expected result not to belong to chain #{expected_chain}, but it did"
    else
      "expected result not to belong to a chain, but it did"
    end
  end

  description do
    desc = "belong to chain"
    desc += " #{expected_chain}" if expected_chain
    desc
  end
end

# Tests that a task result has a specific chain index
#
# This matcher verifies that a result has the expected position index
# within its chain, useful for testing chain execution order and position.
#
# @param [Integer] expected_index The expected chain index (0-based)
#
# @example Basic chain index validation
#   expect(result).to have_chain_index(0)  # First task in chain
#   expect(result).to have_chain_index(2)  # Third task in chain
#
# @example Negated usage
#   expect(result).not_to have_chain_index(1)
#
# @return [Boolean] true if result has the expected chain index
#
# @since 1.0.0
RSpec::Matchers.define :have_chain_index do |expected_index|
  match do |result|
    result.index == expected_index
  end

  failure_message do |result|
    "expected result to have chain index #{expected_index}, but was #{result.index}"
  end

  failure_message_when_negated do |_result|
    "expected result not to have chain index #{expected_index}, but it did"
  end

  description do
    "have chain index #{expected_index}"
  end
end

# Auto-generated predicate matchers for common result states
#
# These matchers are dynamically created for each result state and provide
# convenient boolean testing without requiring the full state name.
#
# Generated matchers:
# - be_initialized: Tests if result is initialized
# - be_executing: Tests if result is executing
# - be_complete: Tests if result is complete
# - be_interrupted: Tests if result is interrupted
#
# @example State predicate usage
#   expect(result).to be_complete
#   expect(result).to be_interrupted
#   expect(result).not_to be_initialized
#
# @since 1.0.0
CMDx::Result::STATES.each do |state|
  RSpec::Matchers.define :"be_#{state}" do
    match do |result|
      result.public_send(:"#{state}?")
    end

    failure_message do |result|
      "expected result to be #{state}, but was #{result.state}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{state}, but it was"
    end

    description do
      "be #{state}"
    end
  end
end

# Auto-generated predicate matchers for common result statuses
#
# These matchers are dynamically created for each result status and provide
# convenient boolean testing without requiring status-specific matchers.
#
# Generated matchers:
# - be_success: Tests if result has success status
# - be_skipped: Tests if result has skipped status
# - be_failed: Tests if result has failed status
#
# @example Status predicate usage
#   expect(result).to be_success
#   expect(result).to be_failed
#   expect(result).not_to be_skipped
#
# @note These are simpler alternatives to the full outcome matchers
#   (be_successful_task, be_failed_task, be_skipped_task) when you only
#   need to test the status without additional validation.
#
# @since 1.0.0
CMDx::Result::STATUSES.each do |status|
  RSpec::Matchers.define :"be_#{status}" do
    match do |result|
      result.public_send(:"#{status}?")
    end

    failure_message do |result|
      "expected result to be #{status}, but was #{result.status}"
    end

    failure_message_when_negated do |_result|
      "expected result not to be #{status}, but it was"
    end

    description do
      "be #{status}"
    end
  end
end

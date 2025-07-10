# frozen_string_literal: true

# RSpec matcher for asserting that a task result has specific metadata.
#
# This matcher checks if a CMDx::Result object's metadata hash contains expected
# key-value pairs. Metadata is typically used to store additional information about
# task execution such as failure reasons, timing details, error contexts, or other
# diagnostic data. The matcher supports both direct value comparisons and RSpec
# matchers for flexible assertions, and can be chained with `including` for
# additional metadata expectations.
#
# @param expected_metadata [Hash] optional hash of expected metadata key-value pairs
#
# @return [Boolean] true if the result's metadata contains all expected pairs
#
# @example Testing basic metadata
#   result = FailedTask.call(data: "invalid")
#   expect(result).to have_metadata(reason: "validation_failed", code: 422)
#
# @example Using RSpec matchers for flexible assertions
#   result = ProcessingTask.call(data: "test")
#   expect(result).to have_metadata(
#     started_at: be_a(Time),
#     duration: be > 0,
#     user_id: be_present
#   )
#
# @example Using the including chain for additional metadata
#   result = ValidationTask.call(data: "invalid")
#   expect(result).to have_metadata(reason: "validation_failed")
#                    .including(field: "email", rule: "format")
#
# @example Testing failure metadata
#   result = DatabaseTask.call(connection: nil)
#   expect(result).to have_metadata(
#     error_class: "ConnectionError",
#     error_message: include("connection failed"),
#     retry_count: 3
#   )
#
# @example Testing skip metadata
#   result = BackupTask.call(force: false)
#   expect(result).to have_metadata(
#     reason: "backup_not_needed",
#     last_backup: be_a(Time),
#     next_backup: be_a(Time)
#   )
#
# @example Negative assertion
#   result = CleanTask.call(data: "valid")
#   expect(result).not_to have_metadata(error_code: anything)
#
# @example Complex metadata validation
#   result = WorkflowTask.call(data: "complex")
#   expect(result).to have_metadata(
#     steps_completed: be >= 5,
#     total_steps: 10,
#     performance_data: be_a(Hash)
#   ).including(
#     memory_usage: be_within(10).of(100),
#     cpu_time: be_positive
#   )
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

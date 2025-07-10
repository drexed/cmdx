# frozen_string_literal: true

# RSpec matcher for asserting that a task result has no metadata.
#
# This matcher checks if a CMDx::Result object's metadata hash is empty.
# Metadata is typically used to store additional information about task execution
# such as failure reasons, timing details, error contexts, or other diagnostic data.
# Testing for empty metadata is useful when verifying that successful tasks execute
# cleanly without generating unnecessary metadata, or when ensuring default states.
#
# @return [Boolean] true if the result's metadata hash is empty
#
# @example Testing successful task with no metadata
#   result = SimpleTask.call(data: "valid")
#   expect(result).to have_empty_metadata
#
# @example Testing clean task execution
#   result = CalculateTask.call(a: 10, b: 20)
#   expect(result).to be_success.and have_empty_metadata
#
# @example Testing default result state
#   result = MyTask.new.result
#   expect(result).to have_empty_metadata
#
# @example Negative assertion - expecting metadata to be present
#   result = ValidationTask.call(data: "invalid")
#   expect(result).not_to have_empty_metadata
#
# @example Comparing with tasks that set metadata
#   successful_result = CleanTask.call(data: "valid")
#   failed_result = FailingTask.call(data: "invalid")
#   expect(successful_result).to have_empty_metadata
#   expect(failed_result).not_to have_empty_metadata
#
# @example Testing metadata cleanup
#   result = ResetTask.call(clear_metadata: true)
#   expect(result).to have_empty_metadata
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

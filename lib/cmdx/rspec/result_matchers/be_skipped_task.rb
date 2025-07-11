# frozen_string_literal: true

# RSpec matcher for asserting that a task result has been skipped with specific conditions.
#
# This matcher checks if a CMDx::Result object is in a skipped state, which means
# the task was executed but was intentionally skipped due to some condition. A result
# is considered skipped when it's in both "skipped" status and "interrupted" state,
# and has been executed. Optionally checks for specific skip reasons and metadata.
#
# @param expected_reason [String, Symbol, nil] optional expected skip reason
#
# @return [Boolean] true if the result is skipped, interrupted, executed, and matches expected criteria
#
# @example Basic usage with skipped task
#   result = ProcessUserTask.call(user_id: 123)
#   expect(result).to be_skipped_task
#
# @example Checking for specific skip reason
#   result = SendEmailTask.call(user: inactive_user)
#   expect(result).to be_skipped_task("user_inactive")
#
# @example Using with_reason chain
#   result = BackupDataTask.call(force: false)
#   expect(result).to be_skipped_task.with_reason(:backup_not_needed)
#
# @example Checking skip with metadata
#   result = ProcessQueueTask.call(queue: empty_queue)
#   expect(result).to be_skipped_task.with_metadata(queue_size: 0, processed_count: 0)
#
# @example Combining reason and metadata checks
#   result = SyncDataTask.call(data: outdated_data)
#   expect(result).to be_skipped_task("data_unchanged").with_metadata(last_sync: timestamp, changes: 0)
#
# @example Negative assertion
#   result = ExecutedTask.call(data: "valid")
#   expect(result).not_to be_skipped_task
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

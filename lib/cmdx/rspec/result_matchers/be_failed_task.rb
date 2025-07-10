# frozen_string_literal: true

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

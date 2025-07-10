# frozen_string_literal: true

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

# frozen_string_literal: true

# RSpec matcher for asserting that a task result has runtime information.
#
# This matcher checks if a CMDx::Result object has recorded runtime information
# from task execution. Runtime represents the elapsed time taken to execute the
# task, measured in seconds as a Float. The matcher can be used to verify that
# runtime was captured, or to test that runtime meets specific expectations
# using direct values or RSpec matchers for performance testing.
#
# @param expected_runtime [Float, RSpec::Matchers::BuiltIn::BaseMatcher, nil]
#   optional expected runtime value or matcher
#
# @return [Boolean] true if the result has runtime and optionally matches expected value
#
# @example Testing that runtime was captured
#   result = ProcessDataTask.call(data: "test")
#   expect(result).to have_runtime
#
# @example Testing specific runtime value
#   result = QuickTask.call(data: "simple")
#   expect(result).to have_runtime(0.1)
#
# @example Testing runtime with RSpec matchers
#   result = ProcessingTask.call(data: "complex")
#   expect(result).to have_runtime(be > 0.5)
#
# @example Testing runtime ranges
#   result = OptimizedTask.call(data: "test")
#   expect(result).to have_runtime(be_between(0.1, 1.0))
#
# @example Testing performance constraints
#   result = PerformanceCriticalTask.call(data: "large_dataset")
#   expect(result).to have_runtime(be < 2.0)
#
# @example Negative assertion for unexecuted tasks
#   result = UnexecutedTask.new.result
#   expect(result).not_to have_runtime
#
# @example Testing runtime precision
#   result = PreciseTask.call(data: "test")
#   expect(result).to have_runtime(be_within(0.01).of(0.25))
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

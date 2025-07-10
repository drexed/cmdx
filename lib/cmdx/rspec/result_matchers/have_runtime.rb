# frozen_string_literal: true

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

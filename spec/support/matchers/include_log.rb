# frozen_string_literal: true

RSpec::Matchers.define :include_log do |string|
  description { "to include substring" }

  match do |templog|
    @string  = string.strip
    @templog = templog.tap(&:rewind).read

    templog.truncate(0)
    templog.rewind

    @templog.include?(@string)
  end

  failure_message do
    "Expected\n#{@templog}\nto include\n#{@string}"
  end

  failure_message_when_negated do
    "Expected\n#{@templog}\nnot to include\n#{@string}"
  end
end

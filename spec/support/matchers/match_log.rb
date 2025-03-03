# frozen_string_literal: true

RSpec::Matchers.define :match_log do |heredoc|
  description { "to match heredoc" }

  match do |templog|
    @heredoc = heredoc.strip
    @templog = templog.tap(&:rewind).read

    templog.truncate(0)
    templog.rewind

    @templog == @heredoc
  end

  failure_message do
    "Expected\n#{@templog}\nto match\n#{@heredoc}"
  end

  failure_message_when_negated do
    "Expected\n#{@templog}\nnot to match\n#{@heredoc}"
  end
end

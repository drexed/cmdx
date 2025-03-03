# frozen_string_literal: true

RSpec::Matchers.define :match_inspect do |heredoc|
  description { "to match heredoc" }

  match do |string|
    @heredoc = heredoc.gsub(/[[:space:]]+/, " ").strip
    @string  = string

    @string == @heredoc
  end

  failure_message do
    "Expected\n#{@string}\nto match\n#{@heredoc}"
  end

  failure_message_when_negated do
    "Expected\n#{@string}\nnot to match\n#{@heredoc}"
  end
end

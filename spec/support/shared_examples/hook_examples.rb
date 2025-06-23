# frozen_string_literal: true

RSpec.shared_examples "task hooks execution" do |expected_hooks|
  it "executes hooks in correct order" do
    expect(result.context.hooks).to eq(expected_hooks)
  end
end

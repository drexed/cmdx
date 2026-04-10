# frozen_string_literal: true

RSpec.describe "Retry behavior" do # rubocop:disable RSpec/DescribeClass
  it "retries on matching exception" do
    attempts = 0

    task = Class.new(CMDx::Task) do
      def self.name = "RetryTask"
      settings retries: { count: 2, retry_on: [RuntimeError], delay: 0 }

      define_method(:work) do
        attempts += 1
        raise "fail" if attempts < 3

        ctx.output = "ok"
      end
    end

    result = task.execute
    expect(result).to be_success
    expect(result.retries).to eq(2)
    expect(attempts).to eq(3)
  end

  it "fails after exhausting retries" do
    attempts = 0

    task = Class.new(CMDx::Task) do
      def self.name = "ExhaustTask"
      settings retries: { count: 1, retry_on: [RuntimeError], delay: 0 }

      define_method(:work) do
        attempts += 1
        raise "always fails"
      end
    end

    result = task.execute
    expect(result).to be_failed
    expect(attempts).to eq(2)
  end
end

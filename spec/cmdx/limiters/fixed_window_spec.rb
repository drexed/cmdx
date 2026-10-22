# frozen_string_literal: true

RSpec.describe CMDx::Limiters::FixedWindow do
  describe ".call" do
    let(:task) { create_task_class(name: "FixedWindowLimiterTask") { define_method(:work) { nil } }.new }
    let(:store_key) { "cmdx:rl:FixedWindowLimiterTask:segment" }
    let(:quota) do
      CMDx::RateLimit::Quota.new(
        task:,
        store_key:,
        max: 2,
        per: 60,
        cost: 1,
        limiter: :fixed_window,
        options: {}
      )
    end

    it "admits until max is reached" do
      first = described_class.call(quota)
      second = described_class.call(quota)

      expect(first).to have_attributes(admitted: true, count: 1, limiter: :fixed_window)
      expect(second).to have_attributes(admitted: true, count: 2, limiter: :fixed_window)
    end

    it "rejects when the window is full" do
      described_class.call(quota)
      described_class.call(quota)
      third = described_class.call(quota)

      expect(third).to have_attributes(admitted: false, count: 3, limiter: :fixed_window)
      expect(third.retry_after).to be_a(Integer)
    end
  end
end

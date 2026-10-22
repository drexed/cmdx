# frozen_string_literal: true

RSpec.describe CMDx::Limiters::LeakyBucket do
  describe ".call" do
    let(:task) { create_task_class(name: "LeakyBucketLimiterTask") { define_method(:work) { nil } }.new }
    let(:store_key) { "cmdx:rl:LeakyBucketLimiterTask:segment" }
    let(:quota) do
      CMDx::RateLimit::Quota.new(
        task:,
        store_key:,
        max: 1,
        per: 60,
        cost: 1,
        limiter: :leaky_bucket,
        options: {}
      )
    end

    it "admits the first request and records the bucket level" do
      admission = described_class.call(quota)

      expect(admission).to have_attributes(admitted: true, level: 1.0, limiter: :leaky_bucket)
    end

    it "rejects when the bucket is full" do
      described_class.call(quota)
      admission = described_class.call(quota)

      expect(admission).to have_attributes(admitted: false, limiter: :leaky_bucket)
      expect(admission.retry_after).to be_a(Integer)
    end

    it "leaks capacity over time" do
      start = Time.utc(2024, 1, 1, 0, 0, 0)
      allow(Time).to receive(:now).and_return(start, start + 120)

      described_class.call(quota)
      admission = described_class.call(quota)

      expect(admission).to have_attributes(admitted: true, limiter: :leaky_bucket)
    end
  end
end

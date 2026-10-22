# frozen_string_literal: true

RSpec.describe CMDx::Executors::Thread do
  describe ".call" do
    it "invokes on_job for each job" do
      seen = Queue.new

      described_class.call(
        jobs: %i[a b c],
        concurrency: 2,
        on_job: ->(job) { seen << job }
      )

      expect(seen.size).to eq(3)
      expect([seen.pop, seen.pop, seen.pop]).to contain_exactly(:a, :b, :c)
    end

    it "raises when concurrency is not a positive Integer" do
      expect do
        described_class.call(jobs: [], concurrency: 0, on_job: ->(_) {})
      end.to raise_error(ArgumentError, /positive Integer/)
    end

    it "re-raises the first error captured from a worker" do
      boom = Class.new(StandardError).new

      expect do
        described_class.call(
          jobs: %i[ok bad],
          concurrency: 1,
          on_job: ->(job) { raise boom if job == :bad }
        )
      end.to raise_error(boom)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Executors::Fiber do
  let(:scheduler) do
    Class.new do
      def fiber(&block)
        fiber = Fiber.new(blocking: false, &block)
        fiber.resume
        fiber
      end

      def close; end
      def block(*); end
      def unblock(*); end
      def kernel_sleep(*); end
      def io_wait(*); end
      def process_wait(*); end
      def fiber_interrupt(*); end
    end.new
  end

  describe ".call" do
    around do |example|
      Thread.new do
        Fiber.set_scheduler(scheduler)
        example.run
      ensure
        Fiber.set_scheduler(nil)
      end.join
    end

    it "invokes on_job for each job when a Fiber.scheduler is installed" do
      seen = []

      described_class.call(
        jobs: %i[a b],
        concurrency: 2,
        on_job: ->(job) { seen << job }
      )

      expect(seen).to contain_exactly(:a, :b)
    end

    it "raises when concurrency is not a positive Integer" do
      expect do
        described_class.call(jobs: [], concurrency: -1, on_job: ->(_) {})
      end.to raise_error(ArgumentError, /positive Integer/)
    end

    it "re-raises the first error captured from a fiber" do
      boom = Class.new(StandardError).new

      expect do
        described_class.call(
          jobs: [:bad],
          concurrency: 1,
          on_job: ->(_) { raise boom }
        )
      end.to raise_error(boom)
    end
  end

  describe ".call without Fiber.scheduler" do
    it "raises a RuntimeError" do
      expect do
        described_class.call(jobs: [:a], concurrency: 1, on_job: ->(_) {})
      end.to raise_error(RuntimeError, /Fiber\.scheduler/)
    end
  end
end

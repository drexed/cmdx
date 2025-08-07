# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Runtime do
  subject(:runtime) { described_class }

  let(:task) { instance_double(CMDx::Task, result: result) }
  let(:result) { instance_double(CMDx::Result, metadata: metadata) }
  let(:metadata) { {} }
  let(:block_result) { "task executed" }
  let(:test_block) { proc { block_result } }

  describe ".call" do
    before do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond)
        .and_return(100, 150) # Start time: 100ms, end time: 150ms
    end

    it "measures runtime and stores it in metadata" do
      result = runtime.call(task, &test_block)

      expect(metadata[:runtime]).to eq(50) # 150 - 100 = 50ms
      expect(result).to eq(block_result)
    end

    it "calls monotonic_time twice to measure duration" do
      runtime.call(task, &test_block)

      expect(Process).to have_received(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond).twice
    end

    it "returns the block result" do
      result = runtime.call(task, &test_block)

      expect(result).to eq(block_result)
    end

    context "when block execution takes no measurable time" do
      before do
        allow(Process).to receive(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC, :millisecond)
          .and_return(100, 100) # Same time
      end

      it "stores zero runtime" do
        runtime.call(task, &test_block)

        expect(metadata[:runtime]).to eq(0)
      end
    end

    context "when block raises an error" do
      let(:error_block) { proc { raise StandardError, "test error" } }

      before do
        allow(Process).to receive(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC, :millisecond)
          .and_return(100)
      end

      it "re-raises the error without storing runtime" do
        expect do
          runtime.call(task, &error_block)
        end.to raise_error(StandardError, "test error")

        expect(metadata[:runtime]).to be_nil
      end

      it "only calls monotonic_time once before the error" do
        begin
          runtime.call(task, &error_block)
        rescue StandardError
          # Expected to raise
        end

        expect(Process).to have_received(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC, :millisecond).once
      end
    end

    context "with additional options" do
      it "ignores unknown options" do
        expect do
          runtime.call(task, unknown_option: "value", &test_block)
        end.not_to raise_error

        expect(metadata[:runtime]).to eq(50)
      end
    end

    context "when block returns nil" do
      let(:nil_block) { proc {} }

      it "still measures runtime correctly" do
        result = runtime.call(task, &nil_block)

        expect(metadata[:runtime]).to eq(50)
        expect(result).to be_nil
      end
    end

    context "when block returns false" do
      let(:false_block) { proc { false } }

      it "still measures runtime correctly" do
        result = runtime.call(task, &false_block)

        expect(metadata[:runtime]).to eq(50)
        expect(result).to be false
      end
    end
  end

  describe "#monotonic_time" do
    it "uses Process.clock_gettime with CLOCK_MONOTONIC in milliseconds" do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond)
        .and_return(123_456)

      time = runtime.send(:monotonic_time)

      expect(Process).to have_received(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond)
      expect(time).to eq(123_456)
    end
  end
end

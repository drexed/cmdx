# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Runtime, type: :unit do
  subject(:runtime) { described_class }

  let(:task) { double("CMDx::Task", result: result) } # rubocop:disable RSpec/VerifiedDoubles
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
      expect(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond)
        .twice

      runtime.call(task, &test_block)
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
        expect(Process).to receive(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC, :millisecond)
          .once

        begin
          runtime.call(task, &error_block)
        rescue StandardError
          # Expected to raise
        end
      end
    end

    context "with conditional execution using 'if'" do
      before do
        allow(task).to receive(:should_measure_runtime?).and_return(true)
      end

      it "measures runtime when 'if' condition is true" do
        result = runtime.call(task, if: :should_measure_runtime?, &test_block)

        expect(metadata[:runtime]).to eq(50)

        expect(result).to eq(block_result)
      end

      it "skips runtime measurement when 'if' condition is false" do
        allow(task).to receive(:should_measure_runtime?).and_return(false)

        result = runtime.call(task, if: :should_measure_runtime?, &test_block)

        expect(metadata[:runtime]).to be_nil

        expect(result).to eq(block_result)
      end
    end

    context "with conditional execution using 'unless'" do
      before do
        allow(task).to receive(:skip_runtime_measurement?).and_return(false)
      end

      it "measures runtime when 'unless' condition is false" do
        result = runtime.call(task, unless: :skip_runtime_measurement?, &test_block)

        expect(metadata[:runtime]).to eq(50)

        expect(result).to eq(block_result)
      end

      it "skips runtime measurement when 'unless' condition is true" do
        allow(task).to receive(:skip_runtime_measurement?).and_return(true)

        result = runtime.call(task, unless: :skip_runtime_measurement?, &test_block)

        expect(metadata[:runtime]).to be_nil

        expect(result).to eq(block_result)
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

        expect(result).to be(false)
      end
    end
  end

  describe "#monotonic_time" do
    it "uses Process.clock_gettime with CLOCK_MONOTONIC in milliseconds" do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC, :millisecond)
        .and_return(123_456)

      time = runtime.send(:monotonic_time)

      expect(time).to eq(123_456)
    end
  end
end

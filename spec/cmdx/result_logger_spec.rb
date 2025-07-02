# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultLogger do
  describe ".call" do
    let(:logger) { mock_logger }
    let(:task) { mock_task }

    context "when logging a successful result" do
      let(:result) do
        mock_success_result(task: task)
      end

      before do
        allow(task).to receive(:logger).and_return(logger)
      end

      it "logs at info severity level" do
        expect(logger).to receive(:with_level).with(:info).and_yield
        expect(logger).to receive(:info).and_yield

        described_class.call(result)
      end

      it "logs the result object" do
        allow(logger).to receive(:with_level).with(:info).and_yield
        expect(logger).to receive(:info) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end

      it "accesses logger through private method" do
        expect(task).to receive(:logger).and_return(logger)
        allow(logger).to receive(:with_level).and_yield
        allow(logger).to receive(:info)

        described_class.call(result)
      end
    end

    context "when logging a failed result" do
      let(:result) do
        mock_failed_result(task: task)
      end

      before do
        allow(task).to receive(:logger).and_return(logger)
      end

      it "logs at error severity level" do
        expect(logger).to receive(:with_level).with(:error).and_yield
        expect(logger).to receive(:error).and_yield

        described_class.call(result)
      end

      it "logs the failed result object" do
        allow(logger).to receive(:with_level).with(:error).and_yield
        expect(logger).to receive(:error) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end
    end

    context "when logging a skipped result" do
      let(:result) do
        mock_skipped_result(task: task)
      end

      before do
        allow(task).to receive(:logger).and_return(logger)
      end

      it "logs at warn severity level" do
        expect(logger).to receive(:with_level).with(:warn).and_yield
        expect(logger).to receive(:warn).and_yield

        described_class.call(result)
      end

      it "logs the skipped result object" do
        allow(logger).to receive(:with_level).with(:warn).and_yield
        expect(logger).to receive(:warn) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end
    end

    context "when no logger is configured" do
      let(:result) do
        mock_result(task: task)
      end

      before do
        allow(task).to receive(:logger).and_return(nil)
      end

      it "returns early without logging" do
        expect(logger).not_to receive(:with_level)
        expect(logger).not_to receive(:info)
        expect(logger).not_to receive(:error)
        expect(logger).not_to receive(:warn)

        described_class.call(result)
      end

      it "accesses logger but does nothing when nil" do
        expect(task).to receive(:logger).and_return(nil)

        described_class.call(result)
      end
    end

    context "with different result statuses" do
      before do
        allow(task).to receive(:logger).and_return(logger)
      end

      it "maps success status to info level" do
        result = mock_success_result(task: task)

        expect(logger).to receive(:with_level).with(:info)
        allow(logger).to receive(:info)

        described_class.call(result)
      end

      it "maps failed status to error level" do
        result = mock_failed_result(task: task)

        expect(logger).to receive(:with_level).with(:error)
        allow(logger).to receive(:error)

        described_class.call(result)
      end

      it "maps skipped status to warn level" do
        result = mock_skipped_result(task: task)

        expect(logger).to receive(:with_level).with(:warn)
        allow(logger).to receive(:warn)

        described_class.call(result)
      end
    end

    context "with logger integration" do
      let(:actual_logger) { Logger.new(StringIO.new) }
      let(:result) do
        mock_success_result(task: task)
      end

      before do
        allow(task).to receive(:logger).and_return(actual_logger)
      end

      it "works with real logger instance" do
        expect { described_class.call(result) }.not_to raise_error
      end

      it "handles logger method calls correctly" do
        allow(actual_logger).to receive(:with_level).with(:info).and_yield
        expect(actual_logger).to receive(:info)

        described_class.call(result)
      end
    end

    context "with severity level validation" do
      before do
        allow(task).to receive(:logger).and_return(logger)
      end

      it "uses correct severity for success status" do
        result = mock_success_result(task: task)

        expect(logger).to receive(:with_level).with(:info)
        allow(logger).to receive(:info)

        described_class.call(result)
      end

      it "uses correct severity for failed status" do
        result = mock_failed_result(task: task)

        expect(logger).to receive(:with_level).with(:error)
        allow(logger).to receive(:error)

        described_class.call(result)
      end

      it "uses correct severity for skipped status" do
        result = mock_skipped_result(task: task)

        expect(logger).to receive(:with_level).with(:warn)
        allow(logger).to receive(:warn)

        described_class.call(result)
      end
    end

    context "with result object interaction" do
      before do
        allow(task).to receive(:logger).and_return(logger)
        allow(logger).to receive(:with_level).and_yield
      end

      it "passes result object to logger block for success" do
        result = mock_success_result(task: task)

        expect(logger).to receive(:info) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end

      it "passes result object to logger block for failure" do
        result = mock_failed_result(task: task)

        expect(logger).to receive(:error) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end

      it "passes result object to logger block for skip" do
        result = mock_skipped_result(task: task)

        expect(logger).to receive(:warn) do |&block|
          expect(block.call).to eq(result)
        end

        described_class.call(result)
      end
    end
  end
end

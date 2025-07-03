# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Logger do
  describe ".call" do
    let(:task) { mock_task }

    context "when no logger is configured" do
      before do
        allow(task).to receive(:task_setting).with(:logger).and_return(nil)
      end

      it "returns nil" do
        result = described_class.call(task)

        expect(result).to be_nil
      end
    end

    context "when logger is configured" do
      let(:logger) { mock_logger }

      before do
        allow(task).to receive(:task_setting).with(:logger).and_return(logger)
        allow(task).to receive(:task_setting?).with(:log_formatter).and_return(false)
        allow(task).to receive(:task_setting?).with(:log_level).and_return(false)
        allow(logger).to receive(:progname=)
      end

      it "returns the configured logger" do
        result = described_class.call(task)

        expect(result).to eq(logger)
      end

      it "sets the task as progname" do
        described_class.call(task)

        expect(logger).to have_received(:progname=).with(task)
      end

      context "when log formatter is configured" do
        let(:formatter) { double("Formatter") }

        before do
          allow(task).to receive(:task_setting?).with(:log_formatter).and_return(true)
          allow(task).to receive(:task_setting).with(:log_formatter).and_return(formatter)
          allow(logger).to receive(:formatter=)
        end

        it "applies the formatter to logger" do
          described_class.call(task)

          expect(logger).to have_received(:formatter=).with(formatter)
        end

        it "returns the logger with formatter applied" do
          result = described_class.call(task)

          expect(result).to eq(logger)
        end
      end

      context "when log level is configured" do
        let(:log_level) { Logger::DEBUG }

        before do
          allow(task).to receive(:task_setting?).with(:log_level).and_return(true)
          allow(task).to receive(:task_setting).with(:log_level).and_return(log_level)
          allow(logger).to receive(:level=)
        end

        it "applies the log level to logger" do
          described_class.call(task)

          expect(logger).to have_received(:level=).with(log_level)
        end

        it "returns the logger with level applied" do
          result = described_class.call(task)

          expect(result).to eq(logger)
        end
      end

      context "when both formatter and level are configured" do
        let(:formatter) { double("Formatter") }
        let(:log_level) { Logger::WARN }

        before do
          allow(task).to receive(:task_setting?).with(:log_formatter).and_return(true)
          allow(task).to receive(:task_setting).with(:log_formatter).and_return(formatter)
          allow(task).to receive(:task_setting?).with(:log_level).and_return(true)
          allow(task).to receive(:task_setting).with(:log_level).and_return(log_level)
          allow(logger).to receive(:formatter=)
          allow(logger).to receive(:level=)
        end

        it "applies both formatter and level to logger" do
          described_class.call(task)

          expect(logger).to have_received(:formatter=).with(formatter)
          expect(logger).to have_received(:level=).with(log_level)
        end

        it "sets progname after applying configuration" do
          described_class.call(task)

          expect(logger).to have_received(:progname=).with(task)
        end

        it "returns the fully configured logger" do
          result = described_class.call(task)

          expect(result).to eq(logger)
        end
      end

      context "when formatter is not configured but level is configured" do
        let(:log_level) { Logger::INFO }

        before do
          allow(task).to receive(:task_setting?).with(:log_formatter).and_return(false)
          allow(task).to receive(:task_setting?).with(:log_level).and_return(true)
          allow(task).to receive(:task_setting).with(:log_level).and_return(log_level)
          allow(logger).to receive(:level=)
        end

        it "applies only the log level" do
          described_class.call(task)

          expect(logger).to have_received(:level=).with(log_level)
        end

        it "does not attempt to set formatter" do
          expect(logger).not_to receive(:formatter=)

          described_class.call(task)
        end
      end

      context "when level is not configured but formatter is configured" do
        let(:formatter) { double("Formatter") }

        before do
          allow(task).to receive(:task_setting?).with(:log_formatter).and_return(true)
          allow(task).to receive(:task_setting).with(:log_formatter).and_return(formatter)
          allow(task).to receive(:task_setting?).with(:log_level).and_return(false)
          allow(logger).to receive(:formatter=)
        end

        it "applies only the formatter" do
          described_class.call(task)

          expect(logger).to have_received(:formatter=).with(formatter)
        end

        it "does not attempt to set level" do
          expect(logger).not_to receive(:level=)

          described_class.call(task)
        end
      end

      context "when configuration settings are nil" do
        before do
          allow(task).to receive(:task_setting?).with(:log_formatter).and_return(true)
          allow(task).to receive(:task_setting).with(:log_formatter).and_return(nil)
          allow(task).to receive(:task_setting?).with(:log_level).and_return(true)
          allow(task).to receive(:task_setting).with(:log_level).and_return(nil)
          allow(logger).to receive(:formatter=)
          allow(logger).to receive(:level=)
        end

        it "applies nil formatter" do
          described_class.call(task)

          expect(logger).to have_received(:formatter=).with(nil)
        end

        it "applies nil level" do
          described_class.call(task)

          expect(logger).to have_received(:level=).with(nil)
        end

        it "still sets progname" do
          described_class.call(task)

          expect(logger).to have_received(:progname=).with(task)
        end
      end
    end

    context "when task setting methods raise errors" do
      let(:logger) { mock_logger }

      before do
        allow(task).to receive(:task_setting).with(:logger).and_return(logger)
        allow(task).to receive(:task_setting?).with(:log_formatter).and_raise(StandardError, "setting error")
        allow(logger).to receive(:progname=)
      end

      it "allows errors to propagate" do
        expect { described_class.call(task) }.to raise_error(StandardError, "setting error")
      end
    end

    context "when logger assignment methods raise errors" do
      let(:logger) { mock_logger }
      let(:formatter) { double("Formatter") }

      before do
        allow(task).to receive(:task_setting).with(:logger).and_return(logger)
        allow(task).to receive(:task_setting?).with(:log_formatter).and_return(true)
        allow(task).to receive(:task_setting).with(:log_formatter).and_return(formatter)
        allow(task).to receive(:task_setting?).with(:log_level).and_return(false)
        allow(logger).to receive(:formatter=).and_raise(StandardError, "formatter error")
        allow(logger).to receive(:progname=)
      end

      it "allows logger configuration errors to propagate" do
        expect { described_class.call(task) }.to raise_error(StandardError, "formatter error")
      end
    end
  end
end

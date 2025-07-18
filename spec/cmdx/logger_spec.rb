# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Logger do
  describe ".call" do
    let(:mock_logger) { double("Logger") }
    let(:mock_formatter) { double("Formatter") }
    let(:mock_task) { double("Task") }

    context "when task has no logger setting" do
      before do
        allow(mock_task).to receive(:cmd_setting).with(:logger).and_return(nil)
      end

      it "returns nil" do
        result = described_class.call(mock_task)

        expect(result).to be_nil
      end

      it "does not attempt to configure logger settings" do
        expect(mock_task).not_to receive(:cmd_setting?)

        described_class.call(mock_task)
      end
    end

    context "when task has logger but no additional settings" do
      before do
        allow(mock_task).to receive(:cmd_setting).with(:logger).and_return(mock_logger)
        allow(mock_task).to receive(:cmd_setting?).with(:log_formatter).and_return(false)
        allow(mock_task).to receive(:cmd_setting?).with(:log_level).and_return(false)
        allow(mock_logger).to receive(:progname=)
      end

      it "returns the logger" do
        result = described_class.call(mock_task)

        expect(result).to eq(mock_logger)
      end

      it "sets progname to the task" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:progname=).with(mock_task)
      end

      it "does not set formatter" do
        expect(mock_logger).not_to receive(:formatter=)

        described_class.call(mock_task)
      end

      it "does not set level" do
        expect(mock_logger).not_to receive(:level=)

        described_class.call(mock_task)
      end
    end

    context "when task has logger with formatter setting" do
      before do
        allow(mock_task).to receive(:cmd_setting).with(:logger).and_return(mock_logger)
        allow(mock_task).to receive(:cmd_setting?).with(:log_formatter).and_return(true)
        allow(mock_task).to receive(:cmd_setting).with(:log_formatter).and_return(mock_formatter)
        allow(mock_task).to receive(:cmd_setting?).with(:log_level).and_return(false)
        allow(mock_logger).to receive(:formatter=)
        allow(mock_logger).to receive(:progname=)
      end

      it "sets the formatter" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:formatter=).with(mock_formatter)
      end

      it "sets progname to the task" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:progname=).with(mock_task)
      end

      it "returns the configured logger" do
        result = described_class.call(mock_task)

        expect(result).to eq(mock_logger)
      end
    end

    context "when task has logger with level setting" do
      before do
        allow(mock_task).to receive(:cmd_setting).with(:logger).and_return(mock_logger)
        allow(mock_task).to receive(:cmd_setting?).with(:log_formatter).and_return(false)
        allow(mock_task).to receive(:cmd_setting?).with(:log_level).and_return(true)
        allow(mock_task).to receive(:cmd_setting).with(:log_level).and_return(Logger::DEBUG)
        allow(mock_logger).to receive(:level=)
        allow(mock_logger).to receive(:progname=)
      end

      it "sets the level" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:level=).with(Logger::DEBUG)
      end

      it "sets progname to the task" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:progname=).with(mock_task)
      end

      it "returns the configured logger" do
        result = described_class.call(mock_task)

        expect(result).to eq(mock_logger)
      end
    end

    context "when task has logger with both formatter and level settings" do
      before do
        allow(mock_task).to receive(:cmd_setting).with(:logger).and_return(mock_logger)
        allow(mock_task).to receive(:cmd_setting?).with(:log_formatter).and_return(true)
        allow(mock_task).to receive(:cmd_setting).with(:log_formatter).and_return(mock_formatter)
        allow(mock_task).to receive(:cmd_setting?).with(:log_level).and_return(true)
        allow(mock_task).to receive(:cmd_setting).with(:log_level).and_return(Logger::WARN)
        allow(mock_logger).to receive(:formatter=)
        allow(mock_logger).to receive(:level=)
        allow(mock_logger).to receive(:progname=)
      end

      it "sets both formatter and level" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:formatter=).with(mock_formatter)
        expect(mock_logger).to have_received(:level=).with(Logger::WARN)
      end

      it "sets progname to the task" do
        described_class.call(mock_task)

        expect(mock_logger).to have_received(:progname=).with(mock_task)
      end

      it "returns the configured logger" do
        result = described_class.call(mock_task)

        expect(result).to eq(mock_logger)
      end
    end
  end

  describe "integration with tasks" do
    context "with task that has logger configured" do
      let(:string_io) { StringIO.new }
      let(:task_class) do
        local_io = string_io
        create_simple_task(name: "LoggedTask") do
          cmd_settings!(logger: Logger.new(local_io))

          def call
            logger.info("Task executed successfully")
            context.executed = true
          end
        end
      end

      it "provides configured logger to task" do
        result = task_class.call

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)

        string_io.rewind
        logged_content = string_io.read
        expect(logged_content).to include("Task executed successfully")
      end

      it "sets task as progname" do
        task_instance = task_class.new
        logger_configured = described_class.call(task_instance)

        expect(logger_configured.progname).to eq(task_instance)
      end
    end

    context "with task that has custom formatter" do
      let(:string_io) { StringIO.new }
      let(:custom_formatter) do
        Class.new do
          def call(severity, _time, _task, message)
            "CUSTOM: #{severity} - #{message}\n"
          end
        end.new
      end

      let(:task_class) do
        local_io = string_io
        formatter = custom_formatter

        create_simple_task(name: "FormattedLogTask") do
          cmd_settings!(logger: Logger.new(local_io), log_formatter: formatter)

          def call
            logger.warn("Custom formatted message")
            context.executed = true
          end
        end
      end

      it "uses custom formatter" do
        result = task_class.call

        expect(result).to be_successful_task

        string_io.rewind
        logged_content = string_io.read
        expect(logged_content).to include("CUSTOM: WARN")
        expect(logged_content).to include("Custom formatted message")
      end
    end

    context "with task that has custom log level" do
      let(:string_io) { StringIO.new }
      let(:task_class) do
        local_io = string_io

        create_simple_task(name: "LeveledLogTask") do
          cmd_settings!(logger: Logger.new(local_io), log_level: Logger::ERROR)

          def call
            logger.debug("This should not appear")
            logger.info("This should not appear either")
            logger.error("This should appear")
            context.executed = true
          end
        end
      end

      it "respects custom log level" do
        result = task_class.call

        expect(result).to be_successful_task

        string_io.rewind
        logged_content = string_io.read
        expect(logged_content).not_to include("This should not appear")
        expect(logged_content).to include("This should appear")
      end
    end

    context "with task that has no explicit logger configured" do
      let(:task_class) do
        create_simple_task(name: "DefaultLogTask") do
          def call
            context.executed = true
            context.has_logger = !logger.nil?
            context.cmdx_logger_result = !CMDx::Logger.call(self).nil?
          end
        end
      end

      it "uses the default global logger" do
        result = task_class.call

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)
        expect(result.context.has_logger).to be(true)
        expect(result.context.cmdx_logger_result).to be(true)
      end
    end

    context "with task that explicitly sets logger to nil" do
      let(:task_class) do
        create_simple_task(name: "NilLoggerTask") do
          cmd_settings!(logger: nil)

          def call
            context.executed = true
            context.logger_is_nil = CMDx::Logger.call(self).nil?
          end
        end
      end

      it "provides nil logger when explicitly set to nil" do
        result = task_class.call

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)
        expect(result.context.logger_is_nil).to be(true)
      end
    end
  end
end

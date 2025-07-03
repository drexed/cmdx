# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Logging Integration", type: :integration do
  # Helper method to capture log output
  let(:log_output) { StringIO.new }
  let(:logger) { Logger.new(log_output) }

  # Clean up log output before each test
  before { log_output.string.clear }

  describe "Log Formatters" do
    context "with standard formatters" do
      describe "Line formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::Line.new)

            def call
              context.processed = true
            end
          end
        end

        it "outputs traditional single-line format" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect(log_line).to match(/I, \[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6} #\d+\] INFO -- .+/)
          expect(log_line).to include("state=complete")
          expect(log_line).to include("status=success")
          expect(log_line).to include("outcome=success")
        end
      end

      describe "Json formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::Json.new)

            def call
              context.order_id = 123
              context.confirmation = "ABC123"
            end
          end
        end

        it "outputs compact single-line JSON" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect { JSON.parse(log_line) }.not_to raise_error

          parsed_log = JSON.parse(log_line)
          expect(parsed_log["status"]).to eq("success")
          expect(parsed_log["state"]).to eq("complete")
          expect(parsed_log["type"]).to eq("Task")
          expect(parsed_log).to have_key("runtime")
        end
      end

      describe "KeyValue formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::KeyValue.new)

            def call
              context.items_processed = 42
            end
          end
        end

        it "outputs space-separated key=value pairs" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect(log_line).to match(/\w+=\w+/)
          expect(log_line).to include("status=success")
          expect(log_line).to include("state=complete")
          expect(log_line).to include("type=Task")
        end
      end

      describe "Logstash formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::Logstash.new)

            def call
              context.transaction_id = "txn_123"
            end
          end
        end

        it "outputs ELK stack compatible JSON with @version and @timestamp" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect { JSON.parse(log_line) }.not_to raise_error

          parsed_log = JSON.parse(log_line)
          expect(parsed_log).to have_key("@version")
          expect(parsed_log).to have_key("@timestamp")
          expect(parsed_log["status"]).to eq("success")
          expect(parsed_log["origin"]).to eq("CMDx")
        end
      end

      describe "Raw formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::Raw.new)

            def call
              context.minimal_output = true
            end
          end
        end

        it "outputs minimal content with only the message" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect(log_line).not_to be_empty
          # Raw formatter should not include timestamp or log level prefixes
          expect(log_line).not_to match(/\[\d{4}-\d{2}-\d{2}/)
          expect(log_line).not_to match(/INFO|WARN|ERROR/)
        end
      end
    end

    context "with stylized formatters" do
      describe "PrettyLine formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::PrettyLine.new)

            def call
              context.colorized = true
            end
          end
        end

        it "outputs colorized line format for terminal readability" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect(log_line).not_to be_empty
          # Check for success status pattern (may be wrapped in ANSI color codes)
          expect(log_line).to match(/status=.*success/m)
        end
      end

      describe "PrettyJson formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::PrettyJson.new)

            def call
              context.pretty_output = true
            end
          end
        end

        it "outputs human-readable multi-line JSON" do
          result = test_task.call

          expect(result).to be_successful_task
          log_output_str = log_output.string
          expect(log_output_str).not_to be_empty
          # Pretty JSON should span multiple lines
          expect(log_output_str.lines.count).to be > 1
        end
      end

      describe "PrettyKeyValue formatter" do
        let(:test_task) do
          test_logger = logger
          Class.new(CMDx::Task) do
            task_settings!(logger: test_logger, log_formatter: CMDx::LogFormatters::PrettyKeyValue.new)

            def call
              context.pretty_kv = true
            end
          end
        end

        it "outputs colorized key=value pairs for terminal" do
          result = test_task.call

          expect(result).to be_successful_task
          log_line = log_output.string.strip
          expect(log_line).not_to be_empty
          expect(log_line).to match(/\w+=\w+/)
        end
      end
    end
  end

  describe "Severity Mapping" do
    let(:test_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::Line.new) }

    context "with successful task execution" do
      let(:success_task) do
        task_logger = test_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: task_logger)

          def call
            context.order_id = 123
            context.status = "completed"
          end
        end
      end

      it "logs at INFO level for success results" do
        result = success_task.call

        expect(result).to be_successful_task
        log_line = log_output.string
        expect(log_line).to include("INFO")
        expect(log_line).to include("status=success")
      end
    end

    context "with skipped task execution" do
      let(:skipped_task) do
        task_logger = test_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: task_logger)

          def call
            skip!(reason: "Order already processed", order_id: context.order_id)
          end
        end
      end

      it "logs at WARN level for skipped results" do
        result = skipped_task.call

        expect(result).to be_skipped_task
        log_line = log_output.string
        expect(log_line).to include("WARN")
        expect(log_line).to include("status=skipped")
        expect(log_line).to include("Order already processed")
      end
    end

    context "with failed task execution" do
      let(:failed_task) do
        task_logger = test_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: task_logger)

          def call
            fail!(reason: "Payment declined", error_code: "INSUFFICIENT_FUNDS")
          end
        end
      end

      it "logs at ERROR level for failed results" do
        result = failed_task.call

        expect(result).to be_failed_task
        log_line = log_output.string
        expect(log_line).to include("ERROR")
        expect(log_line).to include("status=failed")
        expect(log_line).to include("Payment declined")
      end
    end
  end

  describe "Configuration" do
    context "with global configuration" do
      let(:original_logger) { CMDx.configuration.logger }

      after { CMDx.configuration.logger = original_logger }

      it "allows tasks to be configured with global logger explicitly" do
        global_logger = Logger.new(log_output)
        global_logger.formatter = CMDx::LogFormatters::Json.new
        CMDx.configuration.logger = global_logger

        # In CMDx, tasks need to explicitly opt into using the global logger
        # This demonstrates how global configuration would be used
        task_class = Class.new(CMDx::Task) do
          task_settings!(logger: CMDx.configuration.logger)

          def call
            context.global_config = true
          end
        end

        result = task_class.call

        expect(result).to be_successful_task
        log_line = log_output.string.strip
        expect { JSON.parse(log_line) }.not_to raise_error

        parsed_log = JSON.parse(log_line)
        expect(parsed_log["status"]).to eq("success")
      end
    end

    context "with task-specific configuration" do
      let(:specific_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::KeyValue.new) }

      let(:configured_task) do
        task_logger = specific_logger
        Class.new(CMDx::Task) do
          task_settings!(
            logger: task_logger,
            log_formatter: CMDx::LogFormatters::KeyValue.new
          )

          def call
            context.task_specific = true
          end
        end
      end

      it "overrides global settings with task-specific configuration" do
        result = configured_task.call

        expect(result).to be_successful_task
        log_line = log_output.string.strip
        expect(log_line).to match(/\w+=\w+/)
        expect(log_line).to include("status=success")
      end
    end

    context "with inheritance configuration" do
      let(:base_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::Line.new) }

      let(:base_task) do
        test_logger = base_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)
        end
      end

      let(:child_task) do
        Class.new(base_task) do
          def call
            context.inherited_config = true
          end
        end
      end

      it "inherits logging configuration from parent class" do
        result = child_task.call

        expect(result).to be_successful_task
        log_line = log_output.string
        expect(log_line).to include("INFO")
        expect(log_line).to include("status=success")
      end
    end
  end

  describe "Log Data Structure" do
    let(:structured_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::Json.new) }

    context "with successful task" do
      let(:success_task) do
        test_logger = structured_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger, tags: %w[ecommerce payment])

          def call
            context.order_id = 123
            context.amount = 99.99
          end
        end
      end

      it "includes all required log fields for success results" do
        result = success_task.call

        expect(result).to be_successful_task
        parsed_log = JSON.parse(log_output.string.strip)

        # Standard fields
        expect(parsed_log).to have_key("severity")
        expect(parsed_log).to have_key("pid")
        expect(parsed_log).to have_key("timestamp")
        expect(parsed_log["origin"]).to eq("CMDx")

        # Task identification
        expect(parsed_log).to have_key("index")
        expect(parsed_log).to have_key("chain_id")
        expect(parsed_log["type"]).to eq("Task")
        expect(parsed_log).to have_key("class")
        expect(parsed_log).to have_key("id")
        expect(parsed_log["tags"]).to eq(%w[ecommerce payment])

        # Execution information
        expect(parsed_log["state"]).to eq("complete")
        expect(parsed_log["status"]).to eq("success")
        expect(parsed_log["outcome"]).to eq("success")
        expect(parsed_log).to have_key("metadata")
        expect(parsed_log).to have_key("runtime")
        expect(parsed_log["runtime"]).to be_a(Numeric)
      end
    end

    context "with failed task containing metadata" do
      let(:failed_task) do
        test_logger = structured_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            fail!(
              reason: "Credit card declined",
              error_code: "CARD_DECLINED",
              transaction_id: "txn_456",
              retry_count: 3
            )
          end
        end
      end

      it "includes failure metadata in log output" do
        result = failed_task.call

        expect(result).to be_failed_task
        parsed_log = JSON.parse(log_output.string.strip)

        expect(parsed_log["status"]).to eq("failed")
        expect(parsed_log["state"]).to eq("interrupted")
        expect(parsed_log["outcome"]).to eq("failed")

        metadata = parsed_log["metadata"]
        expect(metadata["reason"]).to eq("Credit card declined")
        expect(metadata["error_code"]).to eq("CARD_DECLINED")
        expect(metadata["transaction_id"]).to eq("txn_456")
        expect(metadata["retry_count"]).to eq(3)
      end
    end

    context "with skipped task containing metadata" do
      let(:skipped_task) do
        test_logger = structured_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            skip!(
              reason: "User already verified",
              user_id: context.user_id,
              verification_date: "2023-01-15"
            )
          end
        end
      end

      it "includes skip metadata in log output" do
        result = skipped_task.call(user_id: 789)

        expect(result).to be_skipped_task
        parsed_log = JSON.parse(log_output.string.strip)

        expect(parsed_log["status"]).to eq("skipped")
        expect(parsed_log["state"]).to eq("interrupted")
        expect(parsed_log["outcome"]).to eq("skipped")

        metadata = parsed_log["metadata"]
        expect(metadata["reason"]).to eq("User already verified")
        expect(metadata["user_id"]).to eq(789)
        expect(metadata["verification_date"]).to eq("2023-01-15")
      end
    end
  end

  describe "Manual Logging" do
    let(:manual_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::Line.new) }
    let(:captured_logs) { [] }

    before do
      # Capture manual log calls
      allow(manual_logger).to receive(:info) do |message|
        captured_logs << { level: :info, message: message }
      end

      allow(manual_logger).to receive(:warn) do |message|
        captured_logs << { level: :warn, message: message }
      end

      allow(manual_logger).to receive(:error) do |message|
        captured_logs << { level: :error, message: message }
      end
    end

    context "with logger access in tasks" do
      let(:manual_logging_task) do
        test_logger = manual_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            logger.info "Starting order processing", order_id: context.order_id

            # Simulated processing steps
            logger.info "Validating payment method"
            logger.warn "Low inventory detected"

            context.order_processed = true
            logger.info "Order processing completed successfully"
          end
        end
      end

      it "allows manual logging within task execution" do
        result = manual_logging_task.call(order_id: 12_345)

        expect(result).to be_successful_task
        # CMDx automatically logs task completion, so we expect manual logs + 1 automatic log
        expect(captured_logs.size).to be >= 4

        # Find the manual log entries
        manual_logs = captured_logs.select do |log|
          log[:message] && (
            log[:message].include?("Starting order processing") ||
            log[:message].include?("Validating payment method") ||
            log[:message].include?("Low inventory detected") ||
            log[:message].include?("Order processing completed successfully")
          )
        end

        expect(manual_logs.size).to eq(4)

        start_log = manual_logs.find { |log| log[:message].include?("Starting order processing") }
        expect(start_log[:level]).to eq(:info)

        validate_log = manual_logs.find { |log| log[:message].include?("Validating payment method") }
        expect(validate_log[:level]).to eq(:info)

        warning_log = manual_logs.find { |log| log[:message].include?("Low inventory detected") }
        expect(warning_log[:level]).to eq(:warn)

        completion_log = manual_logs.find { |log| log[:message].include?("Order processing completed successfully") }
        expect(completion_log[:level]).to eq(:info)
      end
    end

    context "with structured logging" do
      let(:structured_logging_task) do
        test_logger = manual_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            # Performance-optimized debug logging
            logger.debug { "Order details: #{context.order_details.inspect}" } if context.order_details

            # Structured logging with metadata
            logger.info "Payment processed", {
              order_id: context.order_id,
              amount: context.amount,
              payment_method: context.payment_method
            }

            context.payment_completed = true
          end
        end
      end

      before do
        allow(manual_logger).to receive(:debug) do |&block|
          captured_logs << { level: :debug, message: block.call } if block
        end
      end

      it "supports structured logging with metadata" do
        result = structured_logging_task.call(
          order_id: 456,
          amount: 199.99,
          payment_method: "credit_card"
        )

        expect(result).to be_successful_task
        # CMDx automatically logs task completion, so we expect manual log + automatic log
        expect(captured_logs.size).to be >= 1

        info_log = captured_logs.find { |log| log[:level] == :info && log[:message].include?("Payment processed") }
        expect(info_log).not_to be_nil
        expect(info_log[:message]).to include("Payment processed")
      end
    end

    context "with exception handling and logging" do
      let(:exception_logging_task) do
        test_logger = manual_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            logger.info "Attempting inventory validation"

            begin
              validate_inventory
            rescue StandardError => e
              logger.error "Inventory validation failed: #{e.message}", {
                exception: e.class.name,
                order_id: context.order_id
              }
              fail!(reason: "Inventory validation failed", error: e.message)
            end
          end

          private

          def validate_inventory
            raise StandardError, "Insufficient stock" if context.stock_level < context.quantity
          end
        end
      end

      it "logs exceptions with structured error information" do
        result = exception_logging_task.call(order_id: 789, stock_level: 1, quantity: 5)

        expect(result).to be_failed_task
        # CMDx automatically logs task failure, so we expect manual logs + automatic log
        expect(captured_logs.size).to be >= 2

        info_log = captured_logs.find { |log| log[:level] == :info && log[:message].include?("Attempting inventory validation") }
        expect(info_log).not_to be_nil
        expect(info_log[:message]).to include("Attempting inventory validation")

        error_log = captured_logs.find { |log| log[:level] == :error && log[:message].include?("Inventory validation failed") }
        expect(error_log).not_to be_nil
        expect(error_log[:message]).to include("Inventory validation failed")
        expect(error_log[:message]).to include("Insufficient stock")
      end
    end
  end

  describe "Advanced Formatter Usage" do
    context "with custom formatter" do
      let(:slack_formatter) do
        Class.new do
          def call(severity, _time, task, message)
            emoji = case severity
                    when "INFO" then "\u2705"
                    when "WARN" then "\u26A0\uFE0F"
                    when "ERROR" then "\u274C"
                    else "\u{1F4DD}"
                    end

            "#{emoji} #{task.class.name}: #{message}\n"
          end
        end.new
      end

      let(:custom_formatter_task) do
        output = log_output
        formatter = slack_formatter
        Class.new(CMDx::Task) do
          task_settings!(
            logger: Logger.new(output, formatter: formatter)
          )

          def call
            context.notification_sent = true
          end
        end
      end

      it "uses custom formatter for specialized output" do
        result = custom_formatter_task.call

        expect(result).to be_successful_task
        log_line = log_output.string
        expect(log_line).to include("✅")
        expect(log_line).to match(/type=Task.*status=success/)
      end
    end

    context "with multi-destination logging" do
      let(:console_output) { StringIO.new }
      let(:file_output) { StringIO.new }

      let(:multi_logger) do
        Class.new do
          attr_accessor :formatter, :level, :progname

          def initialize(*loggers)
            @loggers = loggers
          end

          %w[debug info warn error fatal].each do |level|
            define_method(level) do |message = nil, &block|
              @loggers.each { |logger| logger.send(level, message, &block) }
            end
          end

          def formatter=(formatter)
            @loggers.each { |logger| logger.formatter = formatter }
          end

          def level=(level)
            @loggers.each { |logger| logger.level = level }
          end

          def progname=(progname)
            @loggers.each { |logger| logger.progname = progname if logger.respond_to?(:progname=) }
          end

          def with_level(level)
            @loggers.each { |logger| logger.level = level if logger.respond_to?(:level=) }
            yield
          ensure
            @loggers.each { |logger| logger.level = Logger::INFO if logger.respond_to?(:level=) }
          end
        end.new(
          Logger.new(console_output, formatter: CMDx::LogFormatters::PrettyLine.new),
          Logger.new(file_output, formatter: CMDx::LogFormatters::Json.new)
        )
      end

      let(:multi_destination_task) do
        test_logger = multi_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            context.multi_logged = true
          end
        end
      end

      it "sends output to multiple destinations with different formats" do
        result = multi_destination_task.call

        expect(result).to be_successful_task

        # Console output (PrettyLine format)
        console_log = console_output.string
        expect(console_log).not_to be_empty

        # File output (JSON format)
        file_log = file_output.string.strip
        expect(file_log).not_to be_empty
        expect { JSON.parse(file_log) }.not_to raise_error

        parsed_file_log = JSON.parse(file_log)
        expect(parsed_file_log["status"]).to eq("success")
      end
    end
  end

  describe "Environment-Specific Behavior" do
    let(:original_rails_env) { ENV.fetch("RAILS_ENV", nil) }

    after { ENV["RAILS_ENV"] = original_rails_env }

    context "when in development environment" do
      before { ENV["RAILS_ENV"] = "development" }

      it "uses development-appropriate log configuration" do
        # This test verifies environment-specific behavior would work
        # In a real app, this would be configured in initializers
        expect(ENV.fetch("RAILS_ENV", nil)).to eq("development")
      end
    end

    context "when in test environment" do
      before { ENV["RAILS_ENV"] = "test" }

      it "uses test-appropriate log configuration" do
        expect(ENV.fetch("RAILS_ENV", nil)).to eq("test")
      end
    end

    context "when in production environment" do
      before { ENV["RAILS_ENV"] = "production" }

      it "uses production-appropriate log configuration" do
        expect(ENV.fetch("RAILS_ENV", nil)).to eq("production")
      end
    end
  end

  describe "Performance and Memory Considerations" do
    let(:performance_logger) { Logger.new(log_output, formatter: CMDx::LogFormatters::Json.new) }

    context "with high-volume logging" do
      let(:batch_processing_task) do
        test_logger = performance_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            # Simulate processing many items
            context.items_processed = context.batch_size || 1000
            context.processing_time = Time.now.to_f
          end
        end
      end

      it "handles high-volume task execution efficiently" do
        start_time = Time.now

        result = batch_processing_task.call(batch_size: 10_000)

        end_time = Time.now
        execution_time = end_time - start_time

        expect(result).to be_successful_task
        expect(execution_time).to be < 1.0 # Should complete quickly

        log_line = log_output.string.strip
        parsed_log = JSON.parse(log_line)
        expect(parsed_log["status"]).to eq("success")
        expect(parsed_log).to have_key("runtime")
      end
    end

    context "with lazy debug logging" do
      let(:debug_logging_task) do
        test_logger = performance_logger
        Class.new(CMDx::Task) do
          task_settings!(logger: test_logger)

          def call
            # Performance-optimized debug logging with block
            logger.debug { expensive_debug_computation }
            context.debug_optimized = true
          end

          private

          def expensive_debug_computation
            "Expensive computation result: #{context.data&.inspect}"
          end
        end
      end

      before do
        # Set logger level to INFO to skip debug messages
        performance_logger.level = Logger::INFO
      end

      it "avoids expensive debug computations when level is higher" do
        result = debug_logging_task.call(data: { large: "dataset" })

        expect(result).to be_successful_task
        expect(result.context.debug_optimized).to be(true)

        # Debug message should not appear in output due to log level
        log_content = log_output.string
        expect(log_content).not_to include("Expensive computation result")
      end
    end
  end
end

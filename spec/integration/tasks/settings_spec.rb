# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task settings", type: :feature do
  describe "defaults" do
    let(:task) { create_successful_task }

    it "falls back to the global configuration" do
      config = CMDx.configuration
      expect(task.settings).to have_attributes(
        logger: config.logger,
        log_level: config.log_level,
        log_formatter: config.log_formatter,
        backtrace_cleaner: config.backtrace_cleaner,
        tags: []
      )
    end

    it "builds a per-instance logger via LoggerProxy" do
      instance = task.new
      expect(instance.logger).to be_a(Logger)
    end
  end

  describe "task-level overrides" do
    it "overrides the logger" do
      custom = Logger.new(nil)
      task = create_successful_task { settings(logger: custom) }

      expect(task.settings.logger).to be(custom)
      expect(task.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "overrides tags and surfaces them on the result" do
      task = create_successful_task { settings(tags: %w[billing critical]) }

      expect(task.execute.tags).to eq(%w[billing critical])
    end

    it "applies log_level by dup'ing the base logger" do
      base_logger = Logger.new(nil)
      base_logger.level = Logger::WARN

      task = create_successful_task do
        settings(logger: base_logger, log_level: Logger::DEBUG)
      end

      instance = task.new
      expect(instance.logger).not_to be(base_logger)
      expect(instance.logger.level).to eq(Logger::DEBUG)
      expect(base_logger.level).to eq(Logger::WARN)
    end

    it "applies log_formatter by dup'ing the base logger" do
      formatter = CMDx::LogFormatters::JSON.new
      task = create_successful_task { settings(log_formatter: formatter) }

      expect(task.new.logger.formatter).to be(formatter)
    end

    it "reuses the base logger when neither level nor formatter changes" do
      base_logger = Logger.new(nil)
      base_logger.level = Logger::DEBUG
      base_logger.formatter = proc { |*| "x" }

      task = create_successful_task do
        settings(
          logger: base_logger,
          log_level: Logger::DEBUG,
          log_formatter: base_logger.formatter
        )
      end

      expect(task.new.logger).to be(base_logger)
    end

    it "applies backtrace_cleaner to Fault backtraces" do
      cleaner = ->(bt) { bt.first(2) }
      task = create_failing_task(reason: "broke") { settings(backtrace_cleaner: cleaner) }

      expect(task.settings.backtrace_cleaner).to be(cleaner)
      expect { task.execute! }.to raise_error(CMDx::Fault) do |error|
        expect(error.backtrace.size).to eq(2)
      end
    end
  end

  describe "inheritance" do
    let(:custom_logger) { Logger.new(nil) }
    let(:parent) do
      logger = custom_logger
      create_task_class(name: "Parent") do
        settings(logger:, tags: %w[base])
        define_method(:work) { nil }
      end
    end

    it "inherits parent settings when the child defines none" do
      child = create_task_class(base: parent, name: "PlainChild") { define_method(:work) { nil } }

      expect(child.settings).to have_attributes(logger: custom_logger, tags: %w[base])
    end

    it "merges child overrides on top of inherited settings" do
      child_logger = Logger.new(nil)
      cl = child_logger
      child = create_task_class(base: parent, name: "OverridingChild") do
        settings(logger: cl, tags: %w[override])
        define_method(:work) { nil }
      end

      expect(child.settings).to have_attributes(logger: child_logger, tags: %w[override])
    end

    it "does not leak child settings back to the parent" do
      _child = create_task_class(base: parent, name: "LeakChild") do
        settings(tags: %w[leaked])
        define_method(:work) { nil }
      end

      expect(parent.settings.tags).to eq(%w[base])
    end
  end

  describe "idempotency" do
    it "returns the same Settings instance across reads" do
      task = create_successful_task { settings(tags: %w[a]) }
      first = task.settings

      expect(task.settings).to be(first)
    end
  end

  describe "strict_context" do
    it "defaults to false and allows nil reads of unknown keys" do
      task = create_successful_task do
        define_method(:work) { context.missing }
      end

      expect(task.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "propagates task-level strict_context to the instance context" do
      task = create_task_class(name: "StrictTask") do
        settings(strict_context: true)
        define_method(:work) { nil }
      end

      instance = task.new
      expect(instance.context.strict?).to be(true)
    end

    it "raises NoMethodError inside #work when a dynamic read hits an unknown key" do
      task = create_task_class(name: "StrictReader") do
        settings(strict_context: true)
        define_method(:work) { context.missing }
      end

      expect { task.execute! }.to raise_error(NoMethodError, /unknown context key :missing/)
    end

    it "does not affect [] reads or fetch with defaults" do
      task = create_task_class(name: "StrictSafeReader") do
        settings(strict_context: true)
        define_method(:work) do
          context.seen = context[:missing]
          context.defaulted = context.fetch(:missing, :fallback)
        end
      end

      result = task.execute
      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(result.context).to have_attributes(seen: nil, defaulted: :fallback)
    end

    it "falls back to the global configuration" do
      CMDx.configuration.strict_context = true
      task = create_task_class(name: "GlobalStrict") do
        define_method(:work) { nil }
      end

      expect(task.new.context.strict?).to be(true)
    ensure
      CMDx.configuration.strict_context = false
    end
  end
end

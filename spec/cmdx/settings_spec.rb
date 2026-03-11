# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Settings, type: :unit do
  describe "#initialize" do
    context "without parent" do
      subject(:settings) { described_class.new }

      it "creates fresh registries from configuration" do
        expect(settings.attributes).to be_a(CMDx::AttributeRegistry)
        expect(settings.attributes.registry).to be_empty
        expect(settings.middlewares).to be_a(CMDx::MiddlewareRegistry)
        expect(settings.callbacks).to be_a(CMDx::CallbackRegistry)
        expect(settings.coercions).to be_a(CMDx::CoercionRegistry)
        expect(settings.validators).to be_a(CMDx::ValidatorRegistry)
      end

      it "dups registries so they are independent from configuration" do
        expect(settings.middlewares).not_to equal(CMDx.configuration.middlewares)
        expect(settings.callbacks).not_to equal(CMDx.configuration.callbacks)
        expect(settings.coercions).not_to equal(CMDx.configuration.coercions)
        expect(settings.validators).not_to equal(CMDx.configuration.validators)
      end

      it "inherits scalar values from configuration" do
        expect(settings.task_breakpoints).to eq(CMDx.configuration.task_breakpoints)
        expect(settings.workflow_breakpoints).to eq(CMDx.configuration.workflow_breakpoints)
        expect(settings.rollback_on).to eq(CMDx.configuration.rollback_on)
        expect(settings.backtrace).to eq(CMDx.configuration.backtrace)
        expect(settings.logger).to eq(CMDx.configuration.logger)
      end

      it "initializes nullable fields from configuration" do
        expect(settings.backtrace_cleaner).to eq(CMDx.configuration.backtrace_cleaner)
        expect(settings.exception_handler).to eq(CMDx.configuration.exception_handler)
      end

      it "sets arrays to frozen empty arrays" do
        expect(settings.returns).to eq([])
        expect(settings.returns).to be_frozen
        expect(settings.tags).to eq([])
        expect(settings.tags).to be_frozen
      end

      it "defaults task-level settings to nil" do
        expect(settings.breakpoints).to be_nil
        expect(settings.log_level).to be_nil
        expect(settings.log_formatter).to be_nil
        expect(settings.retries).to be_nil
        expect(settings.retry_on).to be_nil
        expect(settings.retry_jitter).to be_nil
        expect(settings.deprecate).to be_nil
      end
    end

    context "with parent" do
      subject(:settings) { described_class.new(parent: parent) }

      let(:parent) do
        mock_settings(
          attributes: CMDx::AttributeRegistry.new,
          middlewares: CMDx::MiddlewareRegistry.new,
          callbacks: CMDx::CallbackRegistry.new,
          coercions: CMDx::CoercionRegistry.new,
          validators: CMDx::ValidatorRegistry.new,
          task_breakpoints: %w[failed skipped],
          workflow_breakpoints: %w[failed],
          rollback_on: %w[failed],
          breakpoints: %w[failed],
          backtrace: true,
          backtrace_cleaner: ->(bt) { bt.first(3) },
          exception_handler: ->(_task, _err) {},
          logger: Logger.new(nil),
          log_level: Logger::WARN,
          log_formatter: proc { |*| "fmt" },
          retries: 3,
          retry_on: [StandardError, CMDx::TimeoutError],
          retry_jitter: :exponential,
          deprecate: :warn,
          returns: %i[user token],
          tags: %i[auth critical]
        )
      end

      it "deep-dups registries from parent" do
        expect(settings.attributes.registry).to eq(parent.attributes.registry)
        expect(settings.attributes).not_to equal(parent.attributes)

        expect(settings.middlewares).not_to equal(parent.middlewares)
        expect(settings.callbacks).not_to equal(parent.callbacks)
        expect(settings.coercions).not_to equal(parent.coercions)
        expect(settings.validators).not_to equal(parent.validators)
      end

      it "inherits scalar/callable values from parent" do
        expect(settings.task_breakpoints).to eq(%w[failed skipped])
        expect(settings.workflow_breakpoints).to eq(%w[failed])
        expect(settings.rollback_on).to eq(%w[failed])
        expect(settings.breakpoints).to eq(%w[failed])
        expect(settings.backtrace).to be true
        expect(settings.backtrace_cleaner).to eq(parent.backtrace_cleaner)
        expect(settings.exception_handler).to eq(parent.exception_handler)
        expect(settings.logger).to eq(parent.logger)
        expect(settings.log_level).to eq(Logger::WARN)
        expect(settings.log_formatter).to eq(parent.log_formatter)
      end

      it "inherits task-level values from parent" do
        expect(settings.retries).to eq(3)
        expect(settings.retry_on).to eq([StandardError, CMDx::TimeoutError])
        expect(settings.retry_jitter).to eq(:exponential)
        expect(settings.deprecate).to eq(:warn)
      end

      it "dups returns and tags arrays" do
        expect(settings.returns).to eq(%i[user token])
        expect(settings.returns).not_to equal(parent.returns)
        expect(settings.tags).to eq(%i[auth critical])
        expect(settings.tags).not_to equal(parent.tags)
      end

      context "when parent has nil returns and tags" do
        let(:parent) do
          mock_settings(
            attributes: CMDx::AttributeRegistry.new,
            middlewares: CMDx::MiddlewareRegistry.new,
            callbacks: CMDx::CallbackRegistry.new,
            coercions: CMDx::CoercionRegistry.new,
            validators: CMDx::ValidatorRegistry.new,
            task_breakpoints: %w[failed],
            workflow_breakpoints: %w[failed],
            rollback_on: %w[failed],
            breakpoints: nil,
            backtrace: false,
            backtrace_cleaner: nil,
            exception_handler: nil,
            logger: nil,
            log_level: nil,
            log_formatter: nil,
            retries: nil,
            retry_on: nil,
            retry_jitter: nil,
            deprecate: nil,
            returns: nil,
            tags: nil
          )
        end

        it "falls back to frozen empty arrays" do
          expect(settings.returns).to eq([])
          expect(settings.returns).to be_frozen
          expect(settings.tags).to eq([])
          expect(settings.tags).to be_frozen
        end
      end

      context "when parent has nil backtrace_cleaner, exception_handler, and logger" do
        let(:parent) do
          mock_settings(
            attributes: CMDx::AttributeRegistry.new,
            middlewares: CMDx::MiddlewareRegistry.new,
            callbacks: CMDx::CallbackRegistry.new,
            coercions: CMDx::CoercionRegistry.new,
            validators: CMDx::ValidatorRegistry.new,
            task_breakpoints: %w[failed],
            workflow_breakpoints: %w[failed],
            rollback_on: %w[failed],
            breakpoints: nil,
            backtrace: false,
            backtrace_cleaner: nil,
            exception_handler: nil,
            logger: nil,
            log_level: nil,
            log_formatter: nil,
            retries: nil,
            retry_on: nil,
            retry_jitter: nil,
            deprecate: nil,
            returns: nil,
            tags: nil
          )
        end

        it "falls back to configuration values" do
          expect(settings.backtrace_cleaner).to eq(CMDx.configuration.backtrace_cleaner)
          expect(settings.exception_handler).to eq(CMDx.configuration.exception_handler)
          expect(settings.logger).to eq(CMDx.configuration.logger)
        end
      end
    end

    context "with overrides" do
      subject(:settings) { described_class.new(retries: 5, backtrace: true) }

      it "applies overrides after inheriting from configuration" do
        expect(settings.retries).to eq(5)
        expect(settings.backtrace).to be true
      end
    end

    context "with parent and overrides" do
      subject(:settings) { described_class.new(parent: parent, retries: 10, deprecate: :warn) }

      let(:parent) do
        mock_settings(
          attributes: CMDx::AttributeRegistry.new,
          middlewares: CMDx::MiddlewareRegistry.new,
          callbacks: CMDx::CallbackRegistry.new,
          coercions: CMDx::CoercionRegistry.new,
          validators: CMDx::ValidatorRegistry.new,
          task_breakpoints: %w[failed],
          workflow_breakpoints: %w[failed],
          rollback_on: %w[failed],
          breakpoints: nil,
          backtrace: false,
          backtrace_cleaner: nil,
          exception_handler: nil,
          logger: nil,
          log_level: nil,
          log_formatter: nil,
          retries: 2,
          retry_on: nil,
          retry_jitter: nil,
          deprecate: nil,
          returns: nil,
          tags: nil
        )
      end

      it "overrides parent values" do
        expect(settings.retries).to eq(10)
        expect(settings.deprecate).to eq(:warn)
      end
    end
  end

  describe "delegation" do
    context "with delegate_to_configuration settings" do
      it "reflects configuration changes without re-creating settings" do
        settings = described_class.new

        CMDx.configuration.task_breakpoints = %w[failed skipped]
        expect(settings.task_breakpoints).to eq(%w[failed skipped])

        CMDx.configuration.rollback_on = %w[skipped]
        expect(settings.rollback_on).to eq(%w[skipped])
      end

      it "stops delegating once locally overridden" do
        settings = described_class.new
        settings.task_breakpoints = %w[custom]

        CMDx.configuration.task_breakpoints = %w[failed skipped]
        expect(settings.task_breakpoints).to eq(%w[custom])
      end
    end

    context "with delegate_with_fallback settings" do
      it "reflects configuration logger changes" do
        settings = described_class.new
        new_logger = Logger.new(nil)

        CMDx.configuration.logger = new_logger
        expect(settings.logger).to equal(new_logger)
      end

      it "stops delegating once locally overridden" do
        settings = described_class.new
        local_logger = Logger.new(nil)
        settings.logger = local_logger

        CMDx.configuration.logger = Logger.new(nil)
        expect(settings.logger).to equal(local_logger)
      end
    end

    context "with parent chain delegation" do
      it "walks the parent chain to resolve values" do
        grandparent = described_class.new(retries: 5)
        parent = described_class.new(parent: grandparent)
        child = described_class.new(parent: parent)

        expect(child.retries).to eq(5)
      end

      it "prefers the closest override in the chain" do
        grandparent = described_class.new(retries: 5)
        parent = described_class.new(parent: grandparent, retries: 10)
        child = described_class.new(parent: parent)

        expect(child.retries).to eq(10)
      end

      it "local override wins over parent chain" do
        parent = described_class.new(retries: 5)
        child = described_class.new(parent: parent, retries: 20)

        expect(child.retries).to eq(20)
      end
    end
  end
end

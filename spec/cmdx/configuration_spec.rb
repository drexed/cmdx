# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Configuration, type: :unit do
  subject(:configuration) { described_class.new }

  describe "#initialize" do
    it "initializes middlewares registry" do
      expect(configuration.middlewares).to be_a(CMDx::MiddlewareRegistry)
      expect(configuration.middlewares.registry).to be_empty
    end

    it "initializes callbacks registry" do
      expect(configuration.callbacks).to be_a(CMDx::CallbackRegistry)
      expect(configuration.callbacks.registry).to be_empty
    end

    it "initializes coercions registry with default coercions" do
      expect(configuration.coercions).to be_a(CMDx::CoercionRegistry)
      expect(configuration.coercions.registry).to include(
        array: CMDx::Coercions::Array,
        boolean: CMDx::Coercions::Boolean,
        string: CMDx::Coercions::String,
        integer: CMDx::Coercions::Integer,
        float: CMDx::Coercions::Float,
        hash: CMDx::Coercions::Hash,
        big_decimal: CMDx::Coercions::BigDecimal,
        complex: CMDx::Coercions::Complex,
        date: CMDx::Coercions::Date,
        datetime: CMDx::Coercions::DateTime,
        rational: CMDx::Coercions::Rational,
        time: CMDx::Coercions::Time
      )
    end

    it "initializes validators registry with default validators" do
      expect(configuration.validators).to be_a(CMDx::ValidatorRegistry)
      expect(configuration.validators.registry).to include(
        presence: CMDx::Validators::Presence,
        format: CMDx::Validators::Format,
        inclusion: CMDx::Validators::Inclusion,
        exclusion: CMDx::Validators::Exclusion,
        length: CMDx::Validators::Length,
        numeric: CMDx::Validators::Numeric
      )
    end

    it "sets breakpoints to default values" do
      expect(configuration.task_breakpoints).to eq(%w[failed])
      expect(configuration.workflow_breakpoints).to eq(%w[failed])
    end

    it "initializes logger with default configuration" do
      logger = configuration.logger

      expect(logger).to be_a(Logger)
      expect(logger.progname).to eq("cmdx")
      expect(logger.formatter).to be_a(CMDx::LogFormatters::Line)
      expect(logger.level).to eq(Logger::INFO)
    end
  end

  describe "attribute accessors" do
    describe "#middlewares" do
      let(:custom_registry) { CMDx::MiddlewareRegistry.new }

      it "allows setting and getting middlewares" do
        configuration.middlewares = custom_registry

        expect(configuration.middlewares).to eq(custom_registry)
      end

      context "with nil value" do
        it "accepts nil assignment" do
          expect { configuration.middlewares = nil }.not_to raise_error
          expect(configuration.middlewares).to be_nil
        end
      end
    end

    describe "#callbacks" do
      let(:custom_registry) { CMDx::CallbackRegistry.new }

      it "allows setting and getting callbacks" do
        configuration.callbacks = custom_registry

        expect(configuration.callbacks).to eq(custom_registry)
      end

      context "with nil value" do
        it "accepts nil assignment" do
          expect { configuration.callbacks = nil }.not_to raise_error
          expect(configuration.callbacks).to be_nil
        end
      end
    end

    describe "#coercions" do
      let(:custom_registry) { CMDx::CoercionRegistry.new }

      it "allows setting and getting coercions" do
        configuration.coercions = custom_registry

        expect(configuration.coercions).to eq(custom_registry)
      end

      context "with nil value" do
        it "accepts nil assignment" do
          expect { configuration.coercions = nil }.not_to raise_error
          expect(configuration.coercions).to be_nil
        end
      end
    end

    describe "#validators" do
      let(:custom_registry) { CMDx::ValidatorRegistry.new }

      it "allows setting and getting validators" do
        configuration.validators = custom_registry

        expect(configuration.validators).to eq(custom_registry)
      end

      context "with nil value" do
        it "accepts nil assignment" do
          expect { configuration.validators = nil }.not_to raise_error
          expect(configuration.validators).to be_nil
        end
      end
    end

    describe "#task_breakpoints" do
      let(:custom_breakpoints) { %w[failed error timeout] }

      it "allows setting and getting task_breakpoints" do
        configuration.task_breakpoints = custom_breakpoints

        expect(configuration.task_breakpoints).to eq(custom_breakpoints)
      end

      context "with empty array" do
        it "accepts empty array assignment" do
          configuration.task_breakpoints = []

          expect(configuration.task_breakpoints).to eq([])
        end
      end

      context "with nil value" do
        it "accepts nil assignment" do
          configuration.task_breakpoints = nil

          expect(configuration.task_breakpoints).to be_nil
        end
      end
    end

    describe "#workflow_breakpoints" do
      let(:custom_breakpoints) { %w[failed timeout interrupted] }

      it "allows setting and getting workflow_breakpoints" do
        configuration.workflow_breakpoints = custom_breakpoints

        expect(configuration.workflow_breakpoints).to eq(custom_breakpoints)
      end

      context "with empty array" do
        it "accepts empty array assignment" do
          configuration.workflow_breakpoints = []

          expect(configuration.workflow_breakpoints).to eq([])
        end
      end

      context "with nil value" do
        it "accepts nil assignment" do
          configuration.workflow_breakpoints = nil

          expect(configuration.workflow_breakpoints).to be_nil
        end
      end
    end

    describe "#logger" do
      let(:custom_logger) { Logger.new($stderr, progname: "test") }

      it "allows setting and getting logger" do
        configuration.logger = custom_logger

        expect(configuration.logger).to eq(custom_logger)
      end

      context "with nil value" do
        it "accepts nil assignment" do
          expect { configuration.logger = nil }.not_to raise_error
          expect(configuration.logger).to be_nil
        end
      end
    end
  end

  describe "#to_h" do
    let(:result) { configuration.to_h }

    it "returns hash with all configuration attributes" do
      expect(result).to include(
        middlewares: configuration.middlewares,
        callbacks: configuration.callbacks,
        coercions: configuration.coercions,
        validators: configuration.validators,
        task_breakpoints: configuration.task_breakpoints,
        workflow_breakpoints: configuration.workflow_breakpoints,
        logger: configuration.logger
      )
    end

    context "with modified attributes" do
      let(:custom_breakpoints) { %w[custom_failed custom_error] }
      let(:custom_logger) { Logger.new($stderr, progname: "test") }

      before do
        configuration.task_breakpoints = custom_breakpoints
        configuration.logger = custom_logger
      end

      it "reflects the current attribute values" do
        expect(result[:task_breakpoints]).to eq(custom_breakpoints)
        expect(result[:logger]).to eq(custom_logger)
      end
    end

    context "with nil attributes" do
      before do
        configuration.middlewares = nil
        configuration.logger = nil
      end

      it "includes nil values in the hash" do
        expect(result[:middlewares]).to be_nil
        expect(result[:logger]).to be_nil
      end
    end
  end
end

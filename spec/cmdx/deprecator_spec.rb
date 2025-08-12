# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Deprecator do
  let(:mock_task) { instance_double("Task") }
  let(:mock_task_class) { class_double("TaskClass", name: "TestTask") }
  let(:mock_logger) { instance_double("Logger") }
  let(:mock_settings) { { deprecate: deprecate_value } }
  let(:deprecate_value) { false }

  before do
    allow(mock_task_class).to receive(:settings).and_return(mock_settings)
    allow(mock_task).to receive_messages(class: mock_task_class, logger: mock_logger)
    allow(mock_logger).to receive(:warn)
  end

  describe "#restrict" do
    context "when deprecate setting is nil or false" do
      let(:deprecate_value) { nil }

      it "does nothing for nil" do
        expect { described_class.restrict(mock_task) }.not_to raise_error
      end

      context "when deprecate setting is false" do
        let(:deprecate_value) { false }

        it "does nothing for false" do
          expect { described_class.restrict(mock_task) }.not_to raise_error
        end
      end
    end

    context "when deprecate setting is true" do
      let(:deprecate_value) { true }

      it "raises DeprecationError" do
        expect { described_class.restrict(mock_task) }.to raise_error(
          CMDx::DeprecationError, "TestTask usage prohibited"
        )
      end
    end

    context "when deprecate setting contains 'error'" do
      let(:deprecate_value) { "error" }

      it "raises DeprecationError" do
        expect { described_class.restrict(mock_task) }.to raise_error(
          CMDx::DeprecationError, "TestTask usage prohibited"
        )
      end

      context "when deprecate setting is 'custom_error'" do
        let(:deprecate_value) { "custom_error" }

        it "raises DeprecationError" do
          expect { described_class.restrict(mock_task) }.to raise_error(
            CMDx::DeprecationError, "TestTask usage prohibited"
          )
        end
      end
    end

    context "when deprecate setting contains 'log'" do
      let(:deprecate_value) { "log" }

      it "logs a warning message" do
        expect(mock_logger).to receive(:warn)

        described_class.restrict(mock_task)
      end

      context "when deprecate setting is 'custom_log'" do
        let(:deprecate_value) { "custom_log" }

        it "logs a warning message" do
          expect(mock_logger).to receive(:warn)

          described_class.restrict(mock_task)
        end
      end
    end

    context "when deprecate setting contains 'warn'" do
      let(:deprecate_value) { "warn" }

      it "calls warn with deprecation message" do
        expect(described_class).to receive(:warn).with(
          "[TestTask] DEPRECATED: migrate to replacement or discontinue use",
          category: :deprecated
        )

        described_class.restrict(mock_task)
      end

      context "when deprecate setting is 'custom_warn'" do
        let(:deprecate_value) { "custom_warn" }

        it "calls warn with deprecation message" do
          expect(described_class).to receive(:warn).with(
            "[TestTask] DEPRECATED: migrate to replacement or discontinue use",
            category: :deprecated
          )

          described_class.restrict(mock_task)
        end
      end
    end

    context "when deprecate setting is an unknown type" do
      let(:deprecate_value) { "unknown" }

      it "raises an error for unknown deprecation type" do
        expect { described_class.restrict(mock_task) }.to raise_error(
          RuntimeError, 'cannot evaluate "unknown"'
        )
      end
    end

    context "when deprecate setting is a symbol" do
      let(:deprecate_value) { :test_method }

      it "evaluates the symbol and processes the result" do
        allow(mock_task).to receive(:test_method).and_return("symbol_result")

        expect { described_class.restrict(mock_task) }.to raise_error(
          RuntimeError, 'unknown deprecation type "symbol_result"'
        )
      end
    end

    context "when deprecate setting is a proc" do
      let(:deprecate_value) { proc { "log" } }

      it "evaluates the proc and processes the result" do
        expect(mock_logger).to receive(:warn)

        described_class.restrict(mock_task)
      end
    end

    context "when deprecate setting is a callable object" do
      let(:callable_object) { instance_double("Callable", call: "warn") }
      let(:deprecate_value) { callable_object }

      it "calls the object and processes the result" do
        allow(callable_object).to receive(:call).with(mock_task).and_return("warn")
        expect(described_class).to receive(:warn).with(
          "[TestTask] DEPRECATED: migrate to replacement or discontinue use",
          category: :deprecated
        )

        described_class.restrict(mock_task)
      end
    end

    context "when deprecate setting returns a boolean from symbol" do
      let(:deprecate_value) { :check_deprecated }

      it "evaluates symbol and handles boolean result" do
        allow(mock_task).to receive(:check_deprecated).and_return(false)

        expect { described_class.restrict(mock_task) }.not_to raise_error
      end
    end

    context "when deprecate setting returns true from symbol" do
      let(:deprecate_value) { :check_deprecated }

      it "evaluates symbol and raises error for true result" do
        allow(mock_task).to receive(:check_deprecated).and_return(true)

        expect { described_class.restrict(mock_task) }.to raise_error(
          CMDx::DeprecationError, "TestTask usage prohibited"
        )
      end
    end
  end
end

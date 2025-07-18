# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskDeprecator do
  subject(:deprecator) { described_class }

  describe ".call" do
    context "when task has deprecated: :raise setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedRaiseTask") do
          cmd_settings! deprecated: :raise

          def call
            context.executed = true
          end
        end
      end

      let(:task) do
        # Create a basic task object with the required interface
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:raise)
        allow(task).to receive(:class).and_return(task_class)
        task
      end

      it "raises DeprecationError with task name" do
        expect { deprecator.call(task) }.to raise_error(
          CMDx::DeprecationError,
          /DeprecatedRaiseTask\d+ usage prohibited/
        )
      end
    end

    context "when task has deprecated: :log setting" do
      let(:logger_double) { instance_double("Logger") }
      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:log)
        allow(task).to receive(:logger).and_return(logger_double)
        task
      end

      it "logs deprecation warning to task logger" do
        expect(logger_double).to receive(:warn).and_yield

        deprecator.call(task)
      end
    end

    context "when task has deprecated: true setting" do
      let(:logger_double) { instance_double("Logger") }
      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(true)
        allow(task).to receive(:logger).and_return(logger_double)
        task
      end

      it "logs deprecation warning to task logger" do
        expect(logger_double).to receive(:warn).and_yield

        deprecator.call(task)
      end
    end

    context "when task has deprecated: :warn setting" do
      let(:task_class) do
        create_task_class(name: "DeprecatedWarnTask") do
          cmd_settings! deprecated: :warn

          def call
            context.executed = true
          end
        end
      end

      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:warn)
        allow(task).to receive(:class).and_return(task_class)
        task
      end

      it "issues Ruby deprecation warning" do
        expect(deprecator).to receive(:warn) do |message, options|
          expect(message).to match(/\[DeprecatedWarnTask\d+\] DEPRECATED: migrate to replacement or discontinue use/)
          expect(options).to eq(category: :deprecated)
        end

        deprecator.call(task)
      end
    end

    context "when task has no deprecation setting" do
      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(nil)
        task
      end

      it "does not take any action" do
        expect { deprecator.call(task) }.not_to raise_error
      end
    end

    context "when task has deprecated: false setting" do
      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(false)
        task
      end

      it "does not take any action" do
        expect { deprecator.call(task) }.not_to raise_error
      end
    end

    context "when task has unexpected deprecation setting" do
      let(:task) do
        task = double("task")
        allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:unknown_setting)
        task
      end

      it "does not take any action for unknown settings" do
        expect { deprecator.call(task) }.not_to raise_error
      end
    end
  end
end

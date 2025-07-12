# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskDeprecator do
  describe ".call" do
    context "when calling TaskDeprecator directly with mocked task" do
      let(:task) { double("Task") }
      let(:task_class) { double("TaskClass", name: "TestTask") }

      before do
        allow(task).to receive_messages(class: task_class, logger: double("Logger", warn: nil))
      end

      context "when task has deprecated setting set to :raise" do
        before do
          allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:raise)
        end

        it "raises DeprecationError" do
          expect { described_class.call(task) }.to raise_error(CMDx::DeprecationError)
        end

        it "includes task class name in error message" do
          expect { described_class.call(task) }.to raise_error(CMDx::DeprecationError, /TestTask usage prohibited/)
        end
      end

      context "when task has deprecated setting set to :warn" do
        let(:logger) { double("Logger", warn: nil) }

        before do
          allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:warn)
          allow(task).to receive(:logger).and_return(logger)
        end

        it "does not raise an error" do
          expect { described_class.call(task) }.not_to raise_error
        end

        it "warns to stderr with category" do
          expect(described_class).to receive(:warn).with("[TestTask] DEPRECATED: migrate to replacement or discontinue use", category: :deprecated)
          described_class.call(task)
        end

        it "logs warning message with block" do
          expect(logger).to receive(:warn) do |&block|
            expect(block.call).to eq("DEPRECATED: migrate to replacement or discontinue use")
          end
          described_class.call(task)
        end
      end

      context "when task has deprecated setting set to nil" do
        before do
          allow(task).to receive(:cmd_setting).with(:deprecated).and_return(nil)
        end

        it "does not raise an error" do
          expect { described_class.call(task) }.not_to raise_error
        end

        it "does not warn" do
          expect(described_class).not_to receive(:warn)
          described_class.call(task)
        end
      end

      context "when task has deprecated setting set to false" do
        before do
          allow(task).to receive(:cmd_setting).with(:deprecated).and_return(false)
        end

        it "does not raise an error" do
          expect { described_class.call(task) }.not_to raise_error
        end

        it "does not warn" do
          expect(described_class).not_to receive(:warn)
          described_class.call(task)
        end
      end

      context "when task has deprecated setting set to unknown value" do
        before do
          allow(task).to receive(:cmd_setting).with(:deprecated).and_return(:unknown)
        end

        it "does not raise an error" do
          expect { described_class.call(task) }.not_to raise_error
        end

        it "does not warn" do
          expect(described_class).not_to receive(:warn)
          described_class.call(task)
        end
      end
    end
  end
end

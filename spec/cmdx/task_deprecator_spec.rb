# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskDeprecator do
  describe ".call" do
    let(:logger) { double("Logger") }
    let(:task_class) { create_simple_task(name: "TestTask") }
    let(:task) { task_class.new }

    before do
      allow(task).to receive(:logger).and_return(logger)
    end

    context "when task has no deprecated setting" do
      it "returns without doing anything" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(false)
        expect(task).not_to receive(:cmd_setting)
        expect(logger).not_to receive(:warn)
        expect(described_class).not_to receive(:warn)

        expect { described_class.call(task) }.not_to raise_error
      end
    end

    context "when task has deprecated setting set to true" do
      it "raises DeprecationError" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(true)
        expect(task).to receive(:cmd_setting).with(:deprecated).and_return(true)
        expect(task).to receive(:class).and_return(double(name: "TestTask"))

        expect { described_class.call(task) }.to raise_error(CMDx::DeprecationError, "TestTask is deprecated")
      end
    end

    context "when task has deprecated setting set to false" do
      it "logs warning and calls logger.warn" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(true)
        expect(task).to receive(:cmd_setting).with(:deprecated).and_return(false)
        expect(task).to receive(:class).and_return(double(name: "TestTask"))
        expect(logger).to receive(:warn) do |&block|
          expect(block.call).to eq("TestTask will be deprecated. Find a replacement or stop usage")
        end
        expect(described_class).to receive(:warn).with("TestTask will be deprecated. Find a replacement or stop usage", category: :deprecated)

        expect { described_class.call(task) }.not_to raise_error
      end
    end

    context "when task has deprecated setting set to nil" do
      it "logs warning and calls logger.warn" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(true)
        expect(task).to receive(:cmd_setting).with(:deprecated).and_return(nil)
        expect(task).to receive(:class).and_return(double(name: "TestTask"))
        expect(logger).to receive(:warn) do |&block|
          expect(block.call).to eq("TestTask will be deprecated. Find a replacement or stop usage")
        end
        expect(described_class).to receive(:warn).with("TestTask will be deprecated. Find a replacement or stop usage", category: :deprecated)

        expect { described_class.call(task) }.not_to raise_error
      end
    end

    context "when task has deprecated setting set to empty string" do
      it "raises DeprecationError" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(true)
        expect(task).to receive(:cmd_setting).with(:deprecated).and_return("")
        expect(task).to receive(:class).and_return(double(name: "TestTask"))

        expect { described_class.call(task) }.to raise_error(CMDx::DeprecationError, "TestTask is deprecated")
      end
    end

    context "when task has deprecated setting set to truthy value" do
      it "raises DeprecationError" do
        expect(task).to receive(:cmd_setting?).with(:deprecated).and_return(true)
        expect(task).to receive(:cmd_setting).with(:deprecated).and_return("yes")
        expect(task).to receive(:class).and_return(double(name: "TestTask"))

        expect { described_class.call(task) }.to raise_error(CMDx::DeprecationError, "TestTask is deprecated")
      end
    end
  end

  describe "integration tests" do
    context "with a task that has no deprecated setting" do
      let(:task_class) do
        create_simple_task(name: "RegularTask")
      end

      it "does not raise error or log warning" do
        expect(described_class).not_to receive(:warn)

        task = task_class.new
        expect(task).to be_a(task_class)
      end
    end

    context "with a task that is deprecated (true)" do
      let(:task_class) do
        create_simple_task(name: "ObsoleteTask") do
          cmd_settings! deprecated: true
        end
      end

      it "raises DeprecationError" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError, "ObsoleteTask is deprecated")
      end
    end

    context "with a task that will be deprecated (false)" do
      let(:task_class) do
        create_simple_task(name: "LegacyTask") do
          cmd_settings! deprecated: false
        end
      end

      it "logs warning without raising error" do
        expected_message = "LegacyTask will be deprecated. Find a replacement or stop usage"

        expect(described_class).to receive(:warn).with(expected_message, category: :deprecated)

        task = task_class.new
        expect(task).to be_a(task_class)
      end
    end

    context "with a task that has deprecated setting as nil" do
      let(:task_class) do
        create_simple_task(name: "NilDeprecatedTask") do
          cmd_settings! deprecated: nil
        end
      end

      it "logs warning without raising error" do
        expected_message = "NilDeprecatedTask will be deprecated. Find a replacement or stop usage"

        expect(described_class).to receive(:warn).with(expected_message, category: :deprecated)

        task = task_class.new
        expect(task).to be_a(task_class)
      end
    end

    context "with a task that has deprecated setting as empty string" do
      let(:task_class) do
        create_simple_task(name: "EmptyDeprecatedTask") do
          cmd_settings! deprecated: ""
        end
      end

      it "raises DeprecationError" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError, "EmptyDeprecatedTask is deprecated")
      end
    end

    context "with a task that has deprecated setting as truthy string" do
      let(:task_class) do
        create_simple_task(name: "TruthyDeprecatedTask") do
          cmd_settings! deprecated: "yes"
        end
      end

      it "raises DeprecationError" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError, "TruthyDeprecatedTask is deprecated")
      end
    end

    context "with a task that has deprecated setting as number" do
      let(:task_class) do
        create_simple_task(name: "NumberDeprecatedTask") do
          cmd_settings! deprecated: 1
        end
      end

      it "raises DeprecationError" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError, "NumberDeprecatedTask is deprecated")
      end
    end

    context "with a task that has deprecated setting as zero" do
      let(:task_class) do
        create_simple_task(name: "ZeroDeprecatedTask") do
          cmd_settings! deprecated: 0
        end
      end

      it "raises DeprecationError" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError, "ZeroDeprecatedTask is deprecated")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskDeprecator do
  describe ".call" do
    let(:task_class) { create_simple_task(name: "TestTask") }

    context "when task is not deprecated" do
      let(:task_instance) { task_class.new }

      it "returns nothing and does not raise error" do
        expect { described_class.call(task_instance) }.not_to raise_error
      end

      it "returns nil" do
        result = described_class.call(task_instance)
        expect(result).to be_nil
      end
    end

    context "when task is deprecated" do
      before do
        task_class.cmd_settings!(deprecated: true)
      end

      it "raises DeprecationError during task instantiation" do
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "includes task class name in error message" do
        expect { task_class.new }.to raise_error(
          CMDx::DeprecationError,
          "TestTask is deprecated"
        )
      end

      it "raises error with proper exception hierarchy" do
        expect { task_class.new }.to raise_error do |error|
          expect(error).to be_a(CMDx::DeprecationError)
          expect(error).to be_a(CMDx::Error)
          expect(error).to be_a(StandardError)
        end
      end
    end

    context "when deprecated setting is falsy" do
      it "does not raise error when deprecated is false" do
        task_class.cmd_settings!(deprecated: false)
        expect { task_class.new }.not_to raise_error
      end

      it "does not raise error when deprecated is nil" do
        task_class.cmd_settings!(deprecated: nil)
        expect { task_class.new }.not_to raise_error
      end
    end

    context "when deprecated setting is truthy" do
      it "raises error when deprecated is true" do
        task_class.cmd_settings!(deprecated: true)
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "raises error when deprecated is a string" do
        task_class.cmd_settings!(deprecated: "deprecated")
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "raises error when deprecated is a number" do
        task_class.cmd_settings!(deprecated: 1)
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "raises error when deprecated is an empty string (truthy)" do
        task_class.cmd_settings!(deprecated: "")
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "raises error when deprecated is an empty array (truthy)" do
        task_class.cmd_settings!(deprecated: [])
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end

      it "raises error when deprecated is an array with values" do
        task_class.cmd_settings!(deprecated: ["reason"])
        expect { task_class.new }.to raise_error(CMDx::DeprecationError)
      end
    end

    context "with different task class names" do
      it "includes correct class name for named task" do
        named_task_class = create_simple_task(name: "UserRegistrationTask")
        named_task_class.cmd_settings!(deprecated: true)

        expect { named_task_class.new }.to raise_error(
          CMDx::DeprecationError,
          "UserRegistrationTask is deprecated"
        )
      end

      it "includes correct class name for nested class" do
        nested_task_class = create_simple_task(name: "MyApp::Legacy::ProcessorTask")
        nested_task_class.cmd_settings!(deprecated: true)

        expect { nested_task_class.new }.to raise_error(
          CMDx::DeprecationError,
          "MyApp::Legacy::ProcessorTask is deprecated"
        )
      end
    end

    context "when manually calling TaskDeprecator.call" do
      it "properly delegates to task's cmd_setting method" do
        task_instance = task_class.new
        expect(task_instance).to receive(:cmd_setting).with(:deprecated).and_return(false)
        described_class.call(task_instance)
      end

      it "handles cmd_setting returning complex objects" do
        task_instance = task_class.new
        allow(task_instance).to receive(:cmd_setting).with(:deprecated).and_return({ reason: "Legacy API" })
        expect { described_class.call(task_instance) }.to raise_error(CMDx::DeprecationError)
      end

      it "handles cmd_setting returning callable objects" do
        task_instance = task_class.new
        allow(task_instance).to receive(:cmd_setting).with(:deprecated).and_return(-> { true })
        expect { described_class.call(task_instance) }.to raise_error(CMDx::DeprecationError)
      end

      it "handles task that raises error in cmd_setting" do
        task_instance = task_class.new
        allow(task_instance).to receive(:cmd_setting).and_raise(StandardError, "cmd_setting error")
        expect { described_class.call(task_instance) }.to raise_error(StandardError, "cmd_setting error")
      end
    end
  end

  describe "module structure" do
    it "extends itself with module_function" do
      expect(described_class).to respond_to(:call)
      expect(described_class.method(:call)).to be_a(Method)
    end

    it "is a module" do
      expect(described_class).to be_a(Module)
    end

    it "is namespaced under CMDx" do
      expect(described_class.name).to eq("CMDx::TaskDeprecator")
    end
  end
end

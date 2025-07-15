# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Callback do
  subject(:callback) { described_class.new }

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      task = instance_double("Task")
      allow_any_instance_of(described_class).to receive(:call).with(task, :before).and_return("delegated")

      result = described_class.call(task, :before)

      expect(result).to eq("delegated")
    end

    it "passes task and type to instance call method" do
      task = instance_double("Task")
      allow_any_instance_of(described_class).to receive(:call).with(task, :after).and_return("result")

      result = described_class.call(task, :after)

      expect(result).to eq("result")
    end
  end

  describe "#call" do
    it "raises UndefinedCallError with descriptive message" do
      task = instance_double("Task")

      expect { callback.call(task, :before) }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Callback"
      )
    end
  end

  describe "subclass implementation" do
    let(:working_callback_class) do
      Class.new(described_class) do
        def call(task, type)
          "executed_#{type}_for_#{task.class.name}"
        end
      end
    end

    let(:broken_callback_class) do
      Class.new(described_class) do
        # Intentionally doesn't implement call method
      end
    end

    it "works when subclass properly implements call method" do
      task = instance_double("Task", class: double(name: "TestTask"))

      result = working_callback_class.call(task, :before)

      expect(result).to eq("executed_before_for_TestTask")
    end

    it "raises error when subclass doesn't implement call method" do
      task = instance_double("Task")

      expect { broken_callback_class.call(task, :before) }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "callback inheritance" do
    let(:parent_callback_class) do
      Class.new(described_class) do
        def call(_task, type)
          "executed_#{type}"
        end
      end
    end

    let(:child_callback_class) do
      parent_class = parent_callback_class
      Class.new(parent_class) do
        def call(task, type)
          "#{super}_with_child_behavior"
        end
      end
    end

    it "allows subclasses to extend parent behavior" do
      task = instance_double("Task")

      result = child_callback_class.call(task, :before)

      expect(result).to eq("executed_before_with_child_behavior")
    end
  end
end

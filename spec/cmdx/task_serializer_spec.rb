# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskSerializer do
  let(:task_result) do
    double("Result", index: 1)
  end

  let(:task_chain) do
    double("Chain", id: "chain-abc-123")
  end

  let(:task_class) do
    Class.new(CMDx::Task) do
      def self.name
        "ProcessOrderTask"
      end

      task_settings!(tags: %i[order payment])

      def call
        # Implementation
      end
    end
  end

  let(:batch_class) do
    Class.new(CMDx::Batch) do
      def self.name
        "OrderProcessingBatch"
      end

      task_settings!(tags: %i[batch orders])
    end
  end

  let(:task_instance) do
    instance = task_class.new
    allow(instance).to receive_messages(id: "task-def-456", result: task_result, chain: task_chain)
    instance
  end

  let(:batch_instance) do
    instance = batch_class.new
    allow(instance).to receive_messages(id: "batch-ghi-789", result: task_result, chain: task_chain)
    instance
  end

  describe ".call" do
    context "when serializing a task" do
      subject(:serialized_data) { described_class.call(task_instance) }

      it "returns a hash" do
        expect(serialized_data).to be_a(Hash)
      end

      it "includes the task index from result" do
        expect(serialized_data[:index]).to eq(1)
      end

      it "includes the chain id" do
        expect(serialized_data[:chain_id]).to eq("chain-abc-123")
      end

      it "sets type as Task" do
        expect(serialized_data[:type]).to eq("Task")
      end

      it "includes the class name" do
        expect(serialized_data[:class]).to eq("ProcessOrderTask")
      end

      it "includes the task id" do
        expect(serialized_data[:id]).to eq("task-def-456")
      end

      it "includes the task tags" do
        expect(serialized_data[:tags]).to eq(%i[order payment])
      end

      it "includes all expected keys" do
        expected_keys = %i[index chain_id type class id tags]

        expect(serialized_data.keys).to match_array(expected_keys)
      end
    end

    context "when serializing a batch" do
      subject(:serialized_data) { described_class.call(batch_instance) }

      it "returns a hash" do
        expect(serialized_data).to be_a(Hash)
      end

      it "includes the batch index from result" do
        expect(serialized_data[:index]).to eq(1)
      end

      it "includes the chain id" do
        expect(serialized_data[:chain_id]).to eq("chain-abc-123")
      end

      it "sets type as Batch" do
        expect(serialized_data[:type]).to eq("Batch")
      end

      it "includes the class name" do
        expect(serialized_data[:class]).to eq("OrderProcessingBatch")
      end

      it "includes the batch id" do
        expect(serialized_data[:id]).to eq("batch-ghi-789")
      end

      it "includes the batch tags" do
        expect(serialized_data[:tags]).to eq(%i[batch orders])
      end

      it "includes all expected keys" do
        expected_keys = %i[index chain_id type class id tags]

        expect(serialized_data.keys).to match_array(expected_keys)
      end
    end

    context "when task has no tags" do
      let(:tagless_task_class) do
        Class.new(CMDx::Task) do
          def self.name
            "TaglessTask"
          end

          def call
            # Implementation
          end
        end
      end

      let(:tagless_task) do
        instance = tagless_task_class.new
        allow(instance).to receive_messages(id: "task-xyz-999", result: task_result, chain: task_chain)
        instance
      end

      it "includes empty tags array" do
        serialized_data = described_class.call(tagless_task)

        expect(serialized_data[:tags]).to eq([])
      end
    end

    context "when task has different index values" do
      it "serializes index 0" do
        allow(task_result).to receive(:index).and_return(0)
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:index]).to eq(0)
      end

      it "serializes higher index values" do
        allow(task_result).to receive(:index).and_return(42)
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:index]).to eq(42)
      end
    end

    context "when task has different chain ids" do
      it "serializes different chain id format" do
        allow(task_chain).to receive(:id).and_return("550e8400-e29b-41d4-a716-446655440000")
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:chain_id]).to eq("550e8400-e29b-41d4-a716-446655440000")
      end

      it "serializes short chain id" do
        allow(task_chain).to receive(:id).and_return("abc")
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:chain_id]).to eq("abc")
      end
    end

    context "when task has different id formats" do
      it "serializes UUID format id" do
        allow(task_instance).to receive(:id).and_return("550e8400-e29b-41d4-a716-446655440000")
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:id]).to eq("550e8400-e29b-41d4-a716-446655440000")
      end

      it "serializes short id" do
        allow(task_instance).to receive(:id).and_return("xyz")
        serialized_data = described_class.call(task_instance)

        expect(serialized_data[:id]).to eq("xyz")
      end
    end

    context "when task has various tag configurations" do
      it "serializes string tags" do
        task_with_string_tags = Class.new(CMDx::Task) do
          def self.name
            "StringTagTask"
          end

          task_settings!(tags: %w[urgent payment])

          def call
            # Implementation
          end
        end

        instance = task_with_string_tags.new
        allow(instance).to receive_messages(id: "task-str-123", result: task_result, chain: task_chain)

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq(%w[urgent payment])
      end

      it "serializes mixed tag types" do
        task_with_mixed_tags = Class.new(CMDx::Task) do
          def self.name
            "MixedTagTask"
          end

          task_settings!(tags: [:symbol, "string", 123])

          def call
            # Implementation
          end
        end

        instance = task_with_mixed_tags.new
        allow(instance).to receive_messages(id: "task-mix-123", result: task_result, chain: task_chain)

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq([:symbol, "string", 123])
      end

      it "serializes single tag" do
        task_with_single_tag = Class.new(CMDx::Task) do
          def self.name
            "SingleTagTask"
          end

          task_settings!(tags: [:important])

          def call
            # Implementation
          end
        end

        instance = task_with_single_tag.new
        allow(instance).to receive_messages(id: "task-single-123", result: task_result, chain: task_chain)

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq([:important])
      end
    end

    context "when task class has complex names" do
      let(:namespaced_task_class) do
        stub_const("TestNamespace::NamespacedTask", Class.new(CMDx::Task) do
          def call
            # Implementation
          end
        end)
      end

      it "serializes namespaced class name" do
        instance = namespaced_task_class.new
        allow(instance).to receive_messages(id: "namespaced-123", result: task_result, chain: task_chain)

        serialized_data = described_class.call(instance)

        expect(serialized_data[:class]).to eq("TestNamespace::NamespacedTask")
      end
    end
  end
end

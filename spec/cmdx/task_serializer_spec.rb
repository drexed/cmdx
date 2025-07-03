# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskSerializer do
  let(:task_result) do
    mock_result(index: 1)
  end

  let(:task_chain) do
    mock_chain(id: "chain-abc-123")
  end

  let(:task_class) do
    create_task_class(name: "ProcessOrderTask") do
      task_settings!(tags: %i[order payment])

      def call
        # Implementation
      end
    end
  end

  let(:workflow_class) do
    create_workflow_class(name: "OrderProcessingWorkflow") do
      task_settings!(tags: %i[workflow orders])
    end
  end

  let(:task_instance) do
    instance = mock_task(
      id: "task-def-456",
      result: task_result,
      chain: task_chain,
      class: task_class
    )
    allow(instance).to receive(:task_setting).with(:tags).and_return(%i[order payment])
    allow(instance).to receive(:is_a?).with(CMDx::Workflow).and_return(false)
    instance
  end

  let(:workflow_instance) do
    instance = mock_task(
      id: "workflow-ghi-789",
      result: task_result,
      chain: task_chain,
      class: workflow_class
    )
    allow(instance).to receive(:task_setting).with(:tags).and_return(%i[workflow orders])
    allow(instance).to receive(:is_a?).with(CMDx::Workflow).and_return(true)
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

    context "when serializing a workflow" do
      subject(:serialized_data) { described_class.call(workflow_instance) }

      it "returns a hash" do
        expect(serialized_data).to be_a(Hash)
      end

      it "includes the workflow index from result" do
        expect(serialized_data[:index]).to eq(1)
      end

      it "includes the chain id" do
        expect(serialized_data[:chain_id]).to eq("chain-abc-123")
      end

      it "sets type as Workflow" do
        expect(serialized_data[:type]).to eq("Workflow")
      end

      it "includes the class name" do
        expect(serialized_data[:class]).to eq("OrderProcessingWorkflow")
      end

      it "includes the workflow id" do
        expect(serialized_data[:id]).to eq("workflow-ghi-789")
      end

      it "includes the workflow tags" do
        expect(serialized_data[:tags]).to eq(%i[workflow orders])
      end

      it "includes all expected keys" do
        expected_keys = %i[index chain_id type class id tags]

        expect(serialized_data.keys).to match_array(expected_keys)
      end
    end

    context "when task has no tags" do
      let(:tagless_task_class) do
        create_task_class(name: "TaglessTask") do
          def call
            # Implementation
          end
        end
      end

      let(:tagless_task) do
        instance = mock_task(
          id: "task-xyz-999",
          result: task_result,
          chain: task_chain,
          class: tagless_task_class
        )
        allow(instance).to receive(:task_setting).with(:tags).and_return([])
        instance
      end

      it "includes empty tags array" do
        serialized_data = described_class.call(tagless_task)

        expect(serialized_data[:tags]).to eq([])
      end
    end

    context "when task has different index values" do
      it "serializes index 0" do
        task_with_index_zero = mock_task(
          id: "task-def-456",
          result: mock_result(index: 0),
          chain: task_chain,
          class: task_class
        )
        allow(task_with_index_zero).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_index_zero)

        expect(serialized_data[:index]).to eq(0)
      end

      it "serializes higher index values" do
        task_with_high_index = mock_task(
          id: "task-def-456",
          result: mock_result(index: 42),
          chain: task_chain,
          class: task_class
        )
        allow(task_with_high_index).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_high_index)

        expect(serialized_data[:index]).to eq(42)
      end
    end

    context "when task has different chain ids" do
      it "serializes different chain id format" do
        task_with_uuid_chain = mock_task(
          id: "task-def-456",
          result: task_result,
          chain: mock_chain(id: "550e8400-e29b-41d4-a716-446655440000"),
          class: task_class
        )
        allow(task_with_uuid_chain).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_uuid_chain)

        expect(serialized_data[:chain_id]).to eq("550e8400-e29b-41d4-a716-446655440000")
      end

      it "serializes short chain id" do
        task_with_short_chain = mock_task(
          id: "task-def-456",
          result: task_result,
          chain: mock_chain(id: "abc"),
          class: task_class
        )
        allow(task_with_short_chain).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_short_chain)

        expect(serialized_data[:chain_id]).to eq("abc")
      end
    end

    context "when task has different id formats" do
      it "serializes UUID format id" do
        task_with_uuid_id = mock_task(
          id: "550e8400-e29b-41d4-a716-446655440000",
          result: task_result,
          chain: task_chain,
          class: task_class
        )
        allow(task_with_uuid_id).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_uuid_id)

        expect(serialized_data[:id]).to eq("550e8400-e29b-41d4-a716-446655440000")
      end

      it "serializes short id" do
        task_with_short_id = mock_task(
          id: "xyz",
          result: task_result,
          chain: task_chain,
          class: task_class
        )
        allow(task_with_short_id).to receive(:task_setting).with(:tags).and_return(%i[order payment])
        serialized_data = described_class.call(task_with_short_id)

        expect(serialized_data[:id]).to eq("xyz")
      end
    end

    context "when task has various tag configurations" do
      it "serializes string tags" do
        task_with_string_tags = create_task_class(name: "StringTagTask") do
          task_settings!(tags: %w[urgent payment])

          def call
            # Implementation
          end
        end

        instance = mock_task(
          id: "task-str-123",
          result: task_result,
          chain: task_chain,
          class: task_with_string_tags
        )
        allow(instance).to receive(:task_setting).with(:tags).and_return(%w[urgent payment])

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq(%w[urgent payment])
      end

      it "serializes mixed tag types" do
        task_with_mixed_tags = create_task_class(name: "MixedTagTask") do
          task_settings!(tags: [:symbol, "string", 123])

          def call
            # Implementation
          end
        end

        instance = mock_task(
          id: "task-mix-123",
          result: task_result,
          chain: task_chain,
          class: task_with_mixed_tags
        )
        allow(instance).to receive(:task_setting).with(:tags).and_return([:symbol, "string", 123])

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq([:symbol, "string", 123])
      end

      it "serializes single tag" do
        task_with_single_tag = create_task_class(name: "SingleTagTask") do
          task_settings!(tags: [:important])

          def call
            # Implementation
          end
        end

        instance = mock_task(
          id: "task-single-123",
          result: task_result,
          chain: task_chain,
          class: task_with_single_tag
        )
        allow(instance).to receive(:task_setting).with(:tags).and_return([:important])

        serialized_data = described_class.call(instance)

        expect(serialized_data[:tags]).to eq([:important])
      end
    end

    context "when task class has complex names" do
      let(:namespaced_task_class) do
        stub_const("TestNamespace::NamespacedTask", create_task_class(name: "TestNamespace::NamespacedTask") do
          def call
            # Implementation
          end
        end)
      end

      it "serializes namespaced class name" do
        instance = mock_task(
          id: "namespaced-123",
          result: task_result,
          chain: task_chain,
          class: namespaced_task_class
        )
        allow(instance).to receive(:task_setting).with(:tags).and_return([])

        serialized_data = described_class.call(instance)

        expect(serialized_data[:class]).to eq("TestNamespace::NamespacedTask")
      end
    end
  end
end

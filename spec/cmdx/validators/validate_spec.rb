# frozen_string_literal: true

RSpec.describe CMDx::Validators::Validate do
  let(:task_class) do
    create_task_class do
      def nope(v) = "no:#{v}"
    end
  end
  let(:task) { task_class.new }

  describe ".call" do
    it "sends a symbol handler to the task" do
      expect(described_class.call(task, 1, :nope)).to eq("no:1")
    end

    it "invokes a proc via instance_exec on the task" do
      handler = proc { |v| context.object_id.positive? && v }
      expect(described_class.call(task, 42, handler)).to eq(42)
    end

    it "invokes a callable with the value and task" do
      handler = Class.new do
        class << self

          attr_reader :received_task

          def call(value, task)
            @received_task = task
            "x:#{value}"
          end

        end
      end

      expect(described_class.call(task, 1, handler)).to eq("x:1")
      expect(handler.received_task).to be(task)
    end

    it "raises for unsupported handlers" do
      expect { described_class.call(task, 1, Object.new) }
        .to raise_error(ArgumentError, /Symbol, Proc, or respond to #call/)
    end
  end
end

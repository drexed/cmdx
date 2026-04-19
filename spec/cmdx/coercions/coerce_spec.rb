# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Coerce do
  let(:task_class) do
    create_task_class do
      def double_it(v) = v * 2
    end
  end
  let(:task) { task_class.new }

  describe ".call" do
    it "sends a symbol handler to the task" do
      expect(described_class.call(task, 21, :double_it)).to eq(42)
    end

    it "invokes a proc handler via instance_exec on the task" do
      handler = proc { |v| "#{context.class.name}-#{v}" }
      expect(described_class.call(task, 1, handler)).to eq("CMDx::Context-1")
    end

    it "invokes a callable object with the value and task" do
      handler = Class.new do
        class << self

          attr_reader :received_task

          def call(value, task)
            @received_task = task
            value.to_s.reverse
          end

        end
      end

      expect(described_class.call(task, "abc", handler)).to eq("cba")
      expect(handler.received_task).to be(task)
    end

    it "raises for unsupported handlers" do
      expect do
        described_class.call(task, 1, Object.new)
      end.to raise_error(ArgumentError, /must be a Symbol, Proc, or respond to #call/)
    end
  end
end

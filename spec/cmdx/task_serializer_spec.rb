# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskSerializer do
  subject(:result) { SimulationTask.call(simulate:) }

  let(:simulate) { :success }

  describe ".to_h" do
    it "returns serialized attributes" do
      expect(described_class.call(result.task)).to eq(
        index: 0,
        run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        type: "Task",
        class: "SimulationTask",
        id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
        tags: []
      )
    end
  end
end

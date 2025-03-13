# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultSerializer do
  subject(:result) { SimulationTask.call(simulate:) }

  let(:simulate) { :success }

  describe ".to_h" do
    context "when success" do
      it "returns serialized attributes" do
        expect(result.to_h).to eq(
          index: 0,
          run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          type: "Task",
          task: "SimulationTask",
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          outcome: CMDx::Result::SUCCESS,
          state: CMDx::Result::COMPLETE,
          status: CMDx::Result::SUCCESS,
          metadata: {},
          runtime: 0,
          tags: []
        )
      end
    end

    context "when failed" do
      let(:simulate) { :grand_child_failed }

      it "returns serialized attributes" do
        expect(result.to_h).to eq(
          index: 0,
          run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          type: "Task",
          task: "SimulationTask",
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          outcome: CMDx::Result::INTERRUPTED,
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {},
          runtime: 0,
          tags: [],
          caused_failure: {
            task: "SimulationTask",
            id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
            index: 2,
            metadata: {},
            outcome: CMDx::Result::FAILED,
            runtime: 0,
            run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
            state: CMDx::Result::INTERRUPTED,
            status: CMDx::Result::FAILED,
            tags: [],
            type: "Task"
          },
          threw_failure: {
            task: "SimulationTask",
            id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
            index: 1,
            metadata: {},
            outcome: CMDx::Result::INTERRUPTED,
            runtime: 0,
            run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
            state: CMDx::Result::INTERRUPTED,
            status: CMDx::Result::FAILED,
            tags: [],
            type: "Task"
          }
        )
      end
    end
  end
end

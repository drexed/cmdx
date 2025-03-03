# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultInspector do
  subject(:result) { SimulationTask.call(simulate:) }

  let(:simulate) { :success }

  describe ".to_s" do
    context "when success" do
      it "returns stringified attributes" do
        expect(result.to_s).to match_inspect(<<~TEXT)
          SimulationTask:
          type=Task
          index=0
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          state=complete
          status=success
          outcome=success
          metadata={}
          tags=[]
          pid=3784
          runtime=0
        TEXT
      end
    end

    context "when failed" do
      let(:simulate) { :grand_child_failed }

      it "returns stringified attributes" do
        expect(result.to_s).to match_inspect(<<~TEXT)
          SimulationTask:
          type=Task
          index=0
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          state=interrupted
          status=failed
          outcome=interrupted
          metadata={}
          tags=[]
          pid=3784
          runtime=0
          caused_failure=<[2] SimulationTask: 018c2b95-b764-7615-a924-cc5b910ed1e5>
          threw_failure=<[1] SimulationTask: 018c2b95-b764-7615-a924-cc5b910ed1e5>
        TEXT
      end
    end
  end

end

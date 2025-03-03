# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::RunInspector do
  subject(:run) { SimulationTask.call(simulate: :success).run }

  describe ".to_s" do
    it "returns stringified attributes" do
      expect(run.to_s).to eq(<<~TEXT.chomp)
        Run: 018c2b95-b764-7615-a924-cc5b910ed1e5
        =======================================================
        SimulationTask: type=Task index=0 id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=complete status=success outcome=success metadata={} tags=[] pid=3784 runtime=0
        =======================================================
        state=complete status=success outcome=success runtime=0
      TEXT
    end
  end

end

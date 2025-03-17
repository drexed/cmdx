# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line do
  describe ".call" do
    context "when success" do
      it "returns Line formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :success)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          I, [2022-07-17T18:43:15.000000 #3784] INFO -- SimulationTask:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          tags=[]
          state=complete
          status=success
          outcome=success
          metadata={}
          runtime=0
          origin=CMDx
        LINE
      end
    end

    context "when skipped" do
      it "returns Line formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :skipped)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          W, [2022-07-17T18:43:15.000000 #3784] WARN -- SimulationTask:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          tags=[]
          state=interrupted
          status=skipped
          outcome=skipped
          metadata={}
          runtime=0
          origin=CMDx
        LINE
      end
    end

    context "when failed" do
      it "returns Line formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :failed)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          tags=[]
          state=interrupted
          status=failed
          outcome=failed
          metadata={}
          runtime=0
          origin=CMDx
        LINE
      end
    end

    context "when child failed" do
      it "returns Line formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            tags=[]
            state=interrupted
            status=failed
            outcome=interrupted
            metadata={}
            runtime=0
            caused_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
            threw_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
            origin=CMDx
          LINE
        else
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            tags=[]
            state=interrupted
            status=failed
            outcome=interrupted
            metadata={}
            runtime=0
            caused_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
            threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
            origin=CMDx
          LINE
        end
      end
    end

    context "when grand child failed" do
      it "returns Line formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :grand_child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            tags=[]
            state=interrupted
            status=failed
            outcome=interrupted
            metadata={}
            runtime=0
            caused_failure={index: 2, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
            threw_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "interrupted", metadata: {}, runtime: 0}
            origin=CMDx
          LINE
        else
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            tags=[]
            state=interrupted
            status=failed
            outcome=interrupted
            metadata={}
            runtime=0
            caused_failure={:index=>2, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
            threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"interrupted", :metadata=>{}, :runtime=>0}
            origin=CMDx
          LINE
        end
      end
    end
  end
end

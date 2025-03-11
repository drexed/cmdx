# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyLine do
  describe ".call" do
    context "when success" do
      it "returns PrettyLine formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :success)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('I')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('INFO')} -- CMDx:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('complete')}
          status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('success')}
          outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('success')}
          metadata={}
          runtime=0
          tags=[]
          pid=3784
        LINE
      end
    end

    context "when skipped" do
      it "returns PrettyLine formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :skipped)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('W')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('WARN')} -- CMDx:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
          status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('skipped')}
          outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('skipped')}
          metadata={}
          runtime=0
          tags=[]
          pid=3784
        LINE
      end
    end

    context "when failed" do
      it "returns PrettyLine formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :failed)

        expect(local_io).to match_log(<<~LINE.tr("\n", " "))
          #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('E')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('ERROR')} -- CMDx:
          index=0
          run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
          type=Task
          class=SimulationTask
          id=018c2b95-b764-7615-a924-cc5b910ed1e5
          state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
          status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
          outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
          metadata={}
          runtime=0
          tags=[]
          pid=3784
        LINE
      end
    end

    context "when child failed" do
      it "returns PrettyLine formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('E')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('ERROR')} -- CMDx:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
            outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            metadata={}
            runtime=0
            tags=[]
            pid=3784
            caused_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0, tags: [], pid: 3784}
            threw_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0, tags: [], pid: 3784}
          LINE
        else
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('E')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('ERROR')} -- CMDx:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
            outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            metadata={}
            runtime=0
            tags=[]
            pid=3784
            caused_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
            threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
          LINE
        end
      end
    end

    context "when grand child failed" do
      it "returns PrettyLine formatted log line" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :grand_child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('E')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('ERROR')} -- CMDx:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
            outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            metadata={}
            runtime=0
            tags=[]
            pid=3784
            caused_failure={index: 2, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0, tags: [], pid: 3784}
            threw_failure={index: 1, run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", state: "interrupted", status: "failed", outcome: "interrupted", metadata: {}, runtime: 0, tags: [], pid: 3784}
          LINE
        else
          expect(local_io).to match_log(<<~LINE.tr("\n", " "))
            #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('E')}, [2022-07-17T18:43:15.000000 #3784] #{CMDx::LogFormatters::PrettyLine::SEVERITY_ANSI.call('ERROR')} -- CMDx:
            index=0
            run_id=018c2b95-b764-7615-a924-cc5b910ed1e5
            type=Task
            class=SimulationTask
            id=018c2b95-b764-7615-a924-cc5b910ed1e5
            state=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            status=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('failed')}
            outcome=#{CMDx::LogFormatters::PrettyLine::RESULT_ANSI.call('interrupted')}
            metadata={}
            runtime=0
            tags=[]
            pid=3784
            caused_failure={:index=>2, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
            threw_failure={:index=>1, :run_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :state=>"interrupted", :status=>"failed", :outcome=>"interrupted", :metadata=>{}, :runtime=>0, :tags=>[], :pid=>3784}
          LINE
        end
      end
    end
  end
end

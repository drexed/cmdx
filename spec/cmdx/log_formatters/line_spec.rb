# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line do
  let(:expected_success_output) do
    <<~LINE.tr("\n", " ")
      I, [2022-07-17T18:43:15.000000 #3784] INFO -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
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

  let(:expected_skipped_output) do
    <<~LINE.tr("\n", " ")
      W, [2022-07-17T18:43:15.000000 #3784] WARN -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
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

  let(:expected_failed_output) do
    <<~LINE.tr("\n", " ")
      E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
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

  let(:expected_child_failed_output_ruby34) do
    <<~LINE.tr("\n", " ")
      E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
      type=Task
      class=SimulationTask
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      tags=[]
      state=interrupted
      status=failed
      outcome=interrupted
      metadata={}
      runtime=0
      caused_failure={index: 1, chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
      threw_failure={index: 1, chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
      origin=CMDx
    LINE
  end

  let(:expected_child_failed_output_legacy) do
    <<~LINE.tr("\n", " ")
      E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
      type=Task
      class=SimulationTask
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      tags=[]
      state=interrupted
      status=failed
      outcome=interrupted
      metadata={}
      runtime=0
      caused_failure={:index=>1, :chain_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
      threw_failure={:index=>1, :chain_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
      origin=CMDx
    LINE
  end

  let(:expected_grand_child_failed_output_ruby34) do
    <<~LINE.tr("\n", " ")
      E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
      type=Task
      class=SimulationTask
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      tags=[]
      state=interrupted
      status=failed
      outcome=interrupted
      metadata={}
      runtime=0
      caused_failure={index: 2, chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "failed", metadata: {}, runtime: 0}
      threw_failure={index: 1, chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5", type: "Task", class: "SimulationTask", id: "018c2b95-b764-7615-a924-cc5b910ed1e5", tags: [], state: "interrupted", status: "failed", outcome: "interrupted", metadata: {}, runtime: 0}
      origin=CMDx
    LINE
  end

  let(:expected_grand_child_failed_output_legacy) do
    <<~LINE.tr("\n", " ")
      E, [2022-07-17T18:43:15.000000 #3784] ERROR -- SimulationTask:
      index=0
      chain_id=018c2b95-b764-7615-a924-cc5b910ed1e5
      type=Task
      class=SimulationTask
      id=018c2b95-b764-7615-a924-cc5b910ed1e5
      tags=[]
      state=interrupted
      status=failed
      outcome=interrupted
      metadata={}
      runtime=0
      caused_failure={:index=>2, :chain_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"failed", :metadata=>{}, :runtime=>0}
      threw_failure={:index=>1, :chain_id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :type=>"Task", :class=>"SimulationTask", :id=>"018c2b95-b764-7615-a924-cc5b910ed1e5", :tags=>[], :state=>"interrupted", :status=>"failed", :outcome=>"interrupted", :metadata=>{}, :runtime=>0}
      origin=CMDx
    LINE
  end

  it_behaves_like "a comprehensive log formatter"
end

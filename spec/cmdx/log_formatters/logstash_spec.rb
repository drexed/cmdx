# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Logstash do
  let(:expected_success_output) do
    <<~LINE.delete("\n")
      {"index":0,
      "run_id":"018c2b95-b764-7615-a924-cc5b910ed1e5",
      "type":"Task",
      "class":"SimulationTask",
      "id":"018c2b95-b764-7615-a924-cc5b910ed1e5",
      "tags":[],
      "state":"complete",
      "status":"success",
      "outcome":"success",
      "metadata":{},
      "runtime":0,
      "origin":"CMDx",
      "severity":"INFO",
      "pid":3784,
      "@version":"1",
      "@timestamp":"2022-07-17T18:43:15.000000"}
    LINE
  end

  it_behaves_like "a simple log formatter"
end

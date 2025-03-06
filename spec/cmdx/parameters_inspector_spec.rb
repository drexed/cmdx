# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParametersInspector do
  subject(:simulation_task) do
    Class.new(SimulationTask) do
      required :first_name, :last_name
      optional :address, type: :hash do
        required :city
        optional :state, default: "USA", desc: "Alpha-2" do
          optional :zipcode, type: :integer
        end
      end
      required :gender
    end
  end

  describe ".to_s" do
    it "returns stringified attributes" do
      expect(simulation_task.cmd_parameters.to_s).to eq(<<~TXT.gsub("\n", " \n").chomp)
        Parameter: name=first_name type=virtual source=context required=true options={}
        Parameter: name=last_name type=virtual source=context required=true options={}
        Parameter: name=address type=hash source=context required=false options={}
          ↳ Parameter: name=city type=virtual source=address required=true options={}
          ↳ Parameter: name=state type=virtual source=address required=false options={:default=>"USA", :desc=>"Alpha-2"}
            ↳ Parameter: name=zipcode type=integer source=state required=false options={}
        Parameter: name=gender type=virtual source=context required=true options={}
      TXT
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Correlate do
  let(:task_class) do
    Class.new(CMDx::Task) do
      register CMDx::Middlewares::Correlate

      def work; end
    end
  end

  it "sets correlation_id in the context" do
    result = task_class.execute
    id = result.context[:correlation_id]
    expect(id).to be_a(String)
    expect(id).not_to be_empty
  end

  it "reuses an existing correlation_id and still yields" do
    result = task_class.execute(correlation_id: "fixed-id")
    expect(result.context[:correlation_id]).to eq("fixed-id")
    expect(result).to be_success
  end

  it "yields to the block" do
    task = task_class.allocate
    task.instance_variable_set(:@context, CMDx::Context.new)
    ran = false
    described_class.call(task) { ran = true }
    expect(ran).to be(true)
  end
end

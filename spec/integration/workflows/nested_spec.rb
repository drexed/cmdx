# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Nested workflows", type: :feature do
  after { CMDx::Chain.clear }

  describe "nesting a workflow inside another workflow" do
    let(:inner) do
      step = create_task_class(name: "InnerStep") { define_method(:work) { context.inner_done = true } }
      create_workflow_class(name: "InnerWorkflow") { task step }
    end

    let(:outer) do
      inner_wf = inner
      finalize = create_task_class(name: "Finalize") do
        define_method(:work) { context.finalized = context[:inner_done] }
      end
      create_workflow_class(name: "OuterWorkflow") do
        task inner_wf
        task finalize
      end
    end

    it "shares context across the nested workflow" do
      result = outer.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(result.context).to have_attributes(inner_done: true, finalized: true)
    end

    it "records everything under the same cid" do
      result = outer.execute

      expect(result.chain.map(&:cid).uniq.size).to eq(1)
      expect(result.chain.size).to eq(4) # inner_step, inner_wf, finalize, outer_wf
    end
  end

  describe "inner failure propagation" do
    it "halts the outer workflow and skips following tasks" do
      fl = create_failing_task(name: "InnerFail", reason: "inner boom")
      inner = create_workflow_class(name: "InnerFailWf") { task fl }
      after = create_task_class(name: "After") { define_method(:work) { context.ran_after = true } }
      outer = create_workflow_class(name: "OuterFailWf") do
        task inner
        task after
      end

      result = outer.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "inner boom")
      expect(result.context[:ran_after]).to be_nil
    end

    it "captures thrown/caused failure references across boundaries" do
      fl = create_failing_task(name: "InnerFail2", reason: "boom")
      inner = create_workflow_class(name: "InnerFailWf2") { task fl }
      outer = create_workflow_class(name: "OuterFailWf2") { task inner }

      result = outer.execute

      expect(result.caused_failure).not_to be_nil
      expect(result.threw_failure).not_to be_nil
    end
  end

  describe "deep nesting" do
    it "threads context through multiple levels" do
      step = create_task_class(name: "DeepStep") { define_method(:work) { context.deep = true } }
      l3 = create_workflow_class(name: "Level3") { task step }
      l2 = create_workflow_class(name: "Level2") { task l3 }
      l1 = create_workflow_class(name: "Level1") { task l2 }

      expect(l1.execute.context[:deep]).to be(true)
    end
  end

  describe "mixing tasks and nested workflows" do
    it "runs tasks before and after a nested workflow in declaration order" do
      pre = create_task_class(name: "Pre") { define_method(:work) { (context.log ||= []) << :pre } }
      mid = create_task_class(name: "Mid") { define_method(:work) { (context.log ||= []) << :mid } }
      post = create_task_class(name: "Post") { define_method(:work) { (context.log ||= []) << :post } }
      inner = create_workflow_class(name: "Mid") { task mid }

      outer = create_workflow_class(name: "Mixed") do
        task pre
        task inner
        task post
      end

      expect(outer.execute.context[:log]).to eq(%i[pre mid post])
    end
  end
end

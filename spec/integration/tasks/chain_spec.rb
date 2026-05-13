# frozen_string_literal: true

RSpec.describe "Task chain tracking", type: :feature do
  after { CMDx::Chain.clear }

  describe "a root execution with no subtasks" do
    subject(:result) { create_successful_task.execute }

    it "collects only itself and exposes a UUIDv7 cid" do
      expect(result.chain.size).to eq(1)
      expect(result.chain.first).to be(result)
      expect(result.index).to eq(0)
      expect(result.cid).to match(/\A\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
    end
  end

  describe "a nested execution" do
    subject(:result) { create_nested_task(strategy:, status: :success).execute }

    shared_examples "collects the full stack" do
      it "records inner/middle/outer in execution order" do
        expect(result.chain.size).to eq(3)

        names = result.chain.map { |r| r.task.name }
        expect(names.first).to start_with("OuterTask")
        expect(names.last).to start_with("MiddleTask")
      end

      it "indexes each result by its chain position" do
        indexes = result.chain.map(&:index)
        expect(indexes).to eq([0, 1, 2])
      end

      it "shares a single cid across every result" do
        ids = result.chain.map(&:cid).uniq
        expect(ids).to eq([result.cid])
      end

      it "returns all results successful" do
        expect(result.chain).to all(have_attributes(status: CMDx::Signal::SUCCESS))
      end
    end

    context "with swallow strategy" do
      let(:strategy) { :swallow }

      it_behaves_like "collects the full stack"
    end

    context "with throw strategy" do
      let(:strategy) { :throw }

      it_behaves_like "collects the full stack"
    end
  end

  describe "propagating a failed subtask" do
    context "when the outer swallows the failure" do
      subject(:result) { create_nested_task(strategy: :swallow, status: :failure).execute }

      it "keeps the failed inner in the chain but the outer reports success" do
        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
        inner = result.chain.find { |r| r.task.name.start_with?("InnerTask") }
        expect(inner).to have_attributes(status: CMDx::Signal::FAILED)
      end
    end

    context "when the outer throws the failure" do
      subject(:result) { create_nested_task(strategy: :throw, status: :failure).execute }

      it "propagates failure up and still records each layer" do
        expect(result.status).to eq(CMDx::Signal::FAILED)
        expect(result.chain).to all(have_attributes(status: CMDx::Signal::FAILED))
      end
    end
  end

  describe "fiber storage lifecycle" do
    it "clears the chain after a root execution completes" do
      create_nested_task(strategy: :swallow, status: :success).execute

      expect(CMDx::Chain.current).to be_nil
    end

    it "joins a pre-existing chain instead of replacing it" do
      CMDx::Chain.current = CMDx::Chain.new

      first  = create_successful_task.execute
      second = create_successful_task.execute

      expect(first.cid).to eq(second.cid)
      expect(first.chain).to be(second.chain)
      expect(second.index).to eq(1)
      expect(CMDx::Chain.current).not_to be_nil
    end
  end

  describe "isolation between root executions" do
    it "does not leak chain state across runs" do
      first  = create_nested_task(strategy: :swallow, status: :success).execute
      second = create_successful_task.execute

      expect(first.cid).not_to eq(second.cid)
      expect(first.chain.size).to eq(3)
      expect(second.chain.size).to eq(1)
    end
  end
end

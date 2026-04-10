# frozen_string_literal: true

RSpec.describe CMDx::Chain do
  after { described_class.clear }

  describe ".current / .current= / .clear" do
    it "manages thread-local chain" do
      expect(described_class.current).to be_nil

      chain = described_class.new
      described_class.current = chain
      expect(described_class.current).to equal(chain)

      described_class.clear
      expect(described_class.current).to be_nil
    end
  end

  describe "#add" do
    it "adds results with sequential indices" do
      chain = described_class.new
      task = instance_double("CMDx::Task", class: Class.new)

      r1 = CMDx::Result.new(task: task, context: CMDx::Context.new)
      r2 = CMDx::Result.new(task: task, context: CMDx::Context.new)

      chain.add(r1)
      chain.add(r2)

      expect(chain.size).to eq(2)
      expect(r1.index).to eq(0)
      expect(r2.index).to eq(1)
      expect(r1.chain).to equal(chain)
    end
  end

  describe "#id" do
    it "generates a UUID" do
      chain = described_class.new
      expect(chain.id).to match(/\A[0-9a-f-]+\z/)
    end
  end

  describe "depth tracking" do
    it "tracks enter/exit for outermost detection" do
      chain = described_class.new
      expect(chain).to be_outermost

      chain.enter
      expect(chain).not_to be_outermost

      chain.exit
      expect(chain).to be_outermost
    end
  end

  describe "delegation" do
    it "delegates state/status from first result" do
      chain = described_class.new
      task = instance_double("CMDx::Task", class: Class.new)
      r = CMDx::Result.new(task: task, context: CMDx::Context.new)
      r.transition_to_executing!
      r.transition_to_complete!
      chain.add(r)

      expect(chain.state).to eq("complete")
      expect(chain.status).to eq("success")
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Trace do
  describe ".root" do
    it "creates a trace with an id and no parent" do
      trace = described_class.root
      expect(trace.id).to be_a(String)
      expect(trace.parent).to be_nil
    end
  end

  describe "#child" do
    it "creates a linked child trace" do
      parent = described_class.root
      child = parent.child
      expect(child.parent).to eq(parent)
      expect(child.parent_id).to eq(parent.id)
      expect(child.id).not_to eq(parent.id)
    end
  end
end

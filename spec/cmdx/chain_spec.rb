# frozen_string_literal: true

RSpec.describe CMDx::Chain do
  subject(:chain) { described_class.new }

  it "generates an id" do
    expect(chain.id).to be_a(String)
    expect(chain.id).not_to be_empty
  end

  describe ".current" do
    it "is nil by default" do
      expect(described_class.current).to be_nil
    end

    it "can be set and cleared" do
      described_class.current = chain
      expect(described_class.current).to eq(chain)
      described_class.clear
      expect(described_class.current).to be_nil
    end
  end

  describe "#push" do
    it "adds results" do
      outcome = CMDx::Outcome.new
      outcome.executing!
      outcome.complete!
      result = CMDx::Result.new(
        task_id: "1", task_class: String, outcome:,
        context: CMDx::Context.new, errors: CMDx::Errors.new
      )
      chain.push(result)
      expect(chain.size).to eq(1)
      expect(chain.first).to eq(result)
    end
  end

  describe "#freeze" do
    it "freezes results" do
      chain.freeze
      expect(chain).to be_frozen
    end
  end
end

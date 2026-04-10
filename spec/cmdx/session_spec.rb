# frozen_string_literal: true

RSpec.describe CMDx::Session do
  let(:definition) { CMDx::Definition.root }

  describe "initialization" do
    it "creates all session components" do
      session = described_class.new(definition, { name: "test" })
      expect(session.context).to be_a(CMDx::Context)
      expect(session.context[:name]).to eq("test")
      expect(session.outcome).to be_a(CMDx::Outcome)
      expect(session.errors).to be_a(CMDx::Errors)
      expect(session.trace).to be_a(CMDx::Trace)
      expect(session.logger).to be_a(Logger)
    end

    it "symbolizes input keys" do
      session = described_class.new(definition, { "key" => "val" })
      expect(session.raw_input).to eq(key: "val")
    end

    it "accepts a custom trace" do
      trace = CMDx::Trace.root
      session = described_class.new(definition, {}, trace)
      expect(session.trace).to eq(trace)
    end
  end
end

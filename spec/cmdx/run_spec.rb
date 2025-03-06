# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Run do
  subject(:run) { described_class.new(attributes) }

  let(:attributes) { {} }

  describe "#initialize" do
    context "without attributes" do
      it "returns hash of attributes" do
        expect(run).to have_attributes(
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          results: []
        )
      end
    end

    context "with attributes" do
      let(:attributes) do
        {
          id: 123,
          results: [1, 2, 3]
        }
      end

      it "returns hash of attributes" do
        expect(run).to have_attributes(attributes)
      end
    end
  end
end

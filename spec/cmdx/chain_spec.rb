# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  subject(:chain) { described_class.new(attributes) }

  let(:attributes) { {} }

  describe "#initialize" do
    context "when no attributes provided" do
      it "initializes with default attributes" do
        expect(chain).to have_attributes(
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          results: []
        )
      end
    end

    context "when attributes provided" do
      let(:attributes) do
        {
          id: 123,
          results: [1, 2, 3]
        }
      end

      it "initializes with provided attributes" do
        expect(chain).to have_attributes(attributes)
      end
    end
  end
end

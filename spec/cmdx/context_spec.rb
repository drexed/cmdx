# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  subject(:context) { described_class.build(name: "John Doe") }

  describe ".build" do
    context "when building from unfrozen context" do
      it "returns the same context instance" do
        other_context = described_class.build(context)

        expect(context.object_id).to eq(other_context.object_id)
      end
    end

    context "when building from frozen context" do
      it "returns a new context instance" do
        other_context = described_class.build(context.freeze)

        expect(context.object_id).not_to eq(other_context.object_id)
      end
    end
  end
end

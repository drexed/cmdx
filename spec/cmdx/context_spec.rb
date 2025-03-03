# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  subject(:ctx) { described_class.build(name: "John Doe") }

  describe ".build" do
    context "when context is not frozen" do
      it "returns same ctx" do
        other_ctx = described_class.build(ctx)

        expect(ctx.object_id).to eq(other_ctx.object_id)
      end
    end

    context "when context is frozen" do
      it "returns a new ctx" do
        other_ctx = described_class.build(ctx.freeze)

        expect(ctx.object_id).not_to eq(other_ctx.object_id)
      end
    end
  end

end

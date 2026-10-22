# frozen_string_literal: true

RSpec.describe CMDx::Mergers::DeepMerge do
  describe ".call" do
    let(:ctx) { CMDx::Context.build(a: 1, nested: { a: 1 }) }
    let(:result) do
      instance_double(CMDx::Result, context: CMDx::Context.build(b: 2, nested: { b: 2 }))
    end

    it "recursively merges hash values from the parallel task context" do
      described_class.call(ctx, result)

      expect(ctx.a).to eq(1)
      expect(ctx.b).to eq(2)
      expect(ctx.nested).to eq(a: 1, b: 2)
    end

    context "when a key collides with scalar versus hash" do
      let(:ctx) { CMDx::Context.build(nested: 1) }
      let(:result) do
        instance_double(CMDx::Result, context: CMDx::Context.build(nested: { b: 2 }))
      end

      it "replaces the workflow value with the task value" do
        described_class.call(ctx, result)

        expect(ctx.nested).to eq(b: 2)
      end
    end
  end
end

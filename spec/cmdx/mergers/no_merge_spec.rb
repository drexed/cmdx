# frozen_string_literal: true

RSpec.describe CMDx::Mergers::NoMerge do
  describe ".call" do
    let(:ctx) { CMDx::Context.build(a: 1, nested: { a: 1 }) }
    let(:result) do
      instance_double(CMDx::Result, context: CMDx::Context.build(b: 2, nested: { b: 2 }))
    end

    it "leaves the workflow context untouched" do
      described_class.call(ctx, result)

      expect(ctx.a).to eq(1)
      expect(ctx.b).to be_nil
      expect(ctx.nested).to eq(a: 1)
    end
  end
end

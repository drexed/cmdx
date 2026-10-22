# frozen_string_literal: true

RSpec.describe CMDx::Mergers::LastWriteWins do
  describe ".call" do
    let(:ctx) { CMDx::Context.build(a: 1, nested: { a: 1 }) }
    let(:result) do
      instance_double(CMDx::Result, context: CMDx::Context.build(b: 2, nested: { b: 2 }))
    end

    it "shallow-merges the parallel task context into the workflow context" do
      described_class.call(ctx, result)

      expect(ctx.a).to eq(1)
      expect(ctx.b).to eq(2)
      expect(ctx.nested).to eq(b: 2)
    end
  end
end

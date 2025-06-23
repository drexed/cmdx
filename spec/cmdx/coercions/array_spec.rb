# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_coercion) { [] }
  let(:correct_type_value) { [1, 2, 3] }
  let(:coercible_value) { 1 }
  let(:expected_coerced_value) { [1] }

  it_behaves_like "a coercion"

  context "when coercing JSON string" do
    let(:value) { "[1,2,\"b\"]" }

    it "returns parsed array" do
      expect(coercion).to eq([1, 2, "b"])
    end
  end
end

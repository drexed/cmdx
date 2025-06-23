# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a hash" }
  let(:expected_invalid_error_message) { "could not coerce into a hash" }
  let(:correct_type_value) { { a: 1, b: 2 } }
  let(:coercible_value) { [:a, 1, :b, 2] }
  let(:expected_coerced_value) { { a: 1, b: 2 } }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"

  context "when coercing JSON string" do
    let(:value) { "{\"a\":1,\"b\":2}" }

    it "returns parsed hash" do
      expect(coercion).to eq({ "a" => 1, "b" => 2 })
    end
  end
end

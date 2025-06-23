# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a boolean" }
  let(:expected_invalid_error_message) { "could not coerce into a boolean" }
  let(:correct_type_value) { true }
  let(:coercible_value) { "t" }
  let(:expected_coerced_value) { true }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"

  context "when coercing falsey values" do
    let(:value) { "f" }

    it "returns false" do
      expect(coercion).to be(false)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a complex" }
  let(:expected_invalid_error_message) { "could not coerce into a complex" }
  let(:correct_type_value) { Complex(3, 4) }
  let(:coercible_value) { 1.2 }
  let(:expected_coerced_value) { Complex(1.2, 0) }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"
end

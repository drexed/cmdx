# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a big decimal" }
  let(:expected_invalid_error_message) { "could not coerce into a big decimal" }
  let(:correct_type_value) { BigDecimal("123.45") }
  let(:coercible_value) { 1.2 }
  let(:expected_coerced_value) { BigDecimal("1.2") }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a rational" }
  let(:expected_invalid_error_message) { "could not coerce into a rational" }
  let(:correct_type_value) { Rational(3, 4) }
  let(:coercible_value) { "1.2" }
  let(:expected_coerced_value) { Rational(6, 5) }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"
end

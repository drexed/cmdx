# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Float do
  subject(:coercion) { described_class.call(value) }

  let(:expected_nil_error_message) { "could not coerce into a float" }
  let(:expected_invalid_error_message) { "could not coerce into a float" }
  let(:correct_type_value) { 1.2 }
  let(:coercible_value) { 42 }
  let(:expected_coerced_value) { 42.0 }
  let(:invalid_coercible_value) { "abc123" }

  it_behaves_like "a coercion that raises on nil"
end

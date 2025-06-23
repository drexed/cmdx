# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::DateTime do
  subject(:coercion) { described_class.call(value, options) }

  let(:expected_nil_error_message) { "could not coerce into a datetime" }
  let(:expected_invalid_error_message) { "could not coerce into a datetime" }
  let(:expected_type_class) { DateTime }
  let(:correct_type_value) { DateTime.new(2022, 7, 17, 18, 43, 15) }
  let(:invalid_coercible_value) { "abc" }
  let(:format_options) { { format: "%Y-%m-%d" } }
  let(:formatted_input_value) { "2001-02-03" }
  let(:invalid_format_input) { "123" }

  it_behaves_like "a coercion with options"
end

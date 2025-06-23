# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  let(:expected_result_pattern) { "#<CMDx::Result:" }

  it_behaves_like "a raw log formatter"
end

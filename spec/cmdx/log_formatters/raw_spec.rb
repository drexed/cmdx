# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  describe ".call" do
    it "returns Hash formatted log line" do
      local_io = LogFormatterHelpers.simulation_output(described_class, :success)

      expect(local_io).to include_log("#<CMDx::Result:")
    end
  end
end

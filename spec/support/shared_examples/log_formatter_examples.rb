# frozen_string_literal: true

RSpec.shared_examples "a comprehensive log formatter" do
  describe ".call" do
    context "when task succeeds" do
      it "returns correctly formatted success log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :success)
        expect(local_io).to match_log(expected_success_output)
      end
    end

    context "when task is skipped" do
      it "returns correctly formatted skipped log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :skipped)
        expect(local_io).to match_log(expected_skipped_output)
      end
    end

    context "when task fails" do
      it "returns correctly formatted failed log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :failed)
        expect(local_io).to match_log(expected_failed_output)
      end
    end

    context "when child task fails" do
      it "returns correctly formatted child failed log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(expected_child_failed_output_ruby34)
        else
          expect(local_io).to match_log(expected_child_failed_output_legacy)
        end
      end
    end

    context "when grand child task fails" do
      it "returns correctly formatted grand child failed log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :grand_child_failed)

        if RubyVersionHelpers.atleast?(3.4)
          expect(local_io).to match_log(expected_grand_child_failed_output_ruby34)
        else
          expect(local_io).to match_log(expected_grand_child_failed_output_legacy)
        end
      end
    end
  end
end

RSpec.shared_examples "a simple log formatter" do
  describe ".call" do
    context "when task succeeds" do
      it "returns correctly formatted log output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :success)
        expect(local_io).to match_log(expected_success_output)
      end
    end
  end
end

RSpec.shared_examples "a raw log formatter" do
  describe ".call" do
    context "when task succeeds" do
      it "includes result object in output" do
        local_io = LogFormatterHelpers.simulation_output(described_class, :success)
        expect(local_io).to include_log(expected_result_pattern)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.shared_examples "a serializer" do
  describe ".to_h" do
    it "returns serialized attributes" do
      expect(serialized_result).to eq(expected_serialized_attributes)
    end
  end
end

RSpec.shared_examples "an inspector" do
  describe ".to_s" do
    it "returns stringified attributes" do
      expect(inspected_result).to eq(expected_string_output)
    end
  end
end

RSpec.shared_examples "a conditional inspector" do
  describe ".to_s" do
    it "returns stringified attributes" do
      if RubyVersionHelpers.atleast?(3.4)
        expect(inspected_result).to eq(expected_ruby_34_output)
      else
        expect(inspected_result).to eq(expected_legacy_ruby_output)
      end
    end
  end
end

RSpec.shared_examples "a result inspector" do
  describe ".to_s" do
    context "when successful" do
      it "returns stringified attributes" do
        expect(result.to_s).to match_inspect(expected_success_output)
      end
    end

    context "when failed" do
      let(:simulate) { :grand_child_failed }

      it "returns stringified attributes" do
        expect(result.to_s).to match_inspect(expected_failure_output)
      end
    end
  end
end

RSpec.shared_examples "a result serializer" do
  describe ".to_h" do
    context "when successful" do
      it "returns serialized attributes" do
        expect(result.to_h).to eq(expected_success_serialized_attributes)
      end
    end

    context "when failed" do
      let(:simulate) { :grand_child_failed }

      it "returns serialized attributes" do
        expect(result.to_h).to eq(expected_failure_serialized_attributes)
      end
    end
  end
end

RSpec.shared_context "simulation task setup" do
  subject(:result) { SimulationTask.call(simulate: simulate) }

  let(:simulate) { :success }
end

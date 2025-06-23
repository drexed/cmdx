# frozen_string_literal: true

RSpec.shared_examples "a parametric validator" do
  describe ".call" do
    context "when using unsupported options" do
      let(:options) { unsupported_options }

      it "raises ArgumentError for unsupported option" do
        expect { validator }.to raise_error(ArgumentError, expected_unsupported_message)
      end
    end

    context "when using minimum constraint" do
      let(:options) { min_constraint_options }

      context "when value meets minimum" do
        let(:value) { min_valid_value }

        it "returns nil without raising error" do
          expect(validator).to be_nil
        end
      end

      context "when value fails minimum" do
        let(:value) { min_invalid_value }

        it "raises ValidationError with minimum message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_min_message)
        end
      end

      context "with custom message interpolation" do
        let(:options) { min_constraint_options.merge(validator_key => min_constraint_options[validator_key].merge(message: custom_interpolated_message)) }
        let(:value) { min_invalid_value }

        it "raises ValidationError with interpolated message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_interpolated_message)
        end
      end
    end

    context "when using maximum constraint" do
      let(:options) { max_constraint_options }

      context "when value meets maximum" do
        let(:value) { max_valid_value }

        it "returns nil without raising error" do
          expect(validator).to be_nil
        end
      end

      context "when value fails maximum" do
        let(:value) { max_invalid_value }

        it "raises ValidationError with maximum message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_max_message)
        end
      end
    end
  end
end

RSpec.shared_examples "a collection validator" do
  describe ".call" do
    context "when value matches collection criteria" do
      let(:value) { collection_valid_value }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value fails collection criteria" do
      let(:value) { collection_invalid_value }

      context "with default message" do
        it "raises ValidationError with collection message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_collection_message)
        end
      end

      context "with custom message" do
        let(:options) { base_options.merge(validator_key => base_options[validator_key].merge(message: "custom message")) }

        it "raises ValidationError with custom message" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end
end

RSpec.shared_examples "a coercion" do
  describe ".call" do
    context "when value is nil" do
      let(:value) { nil }

      it "returns expected nil coercion" do
        expect(coercion).to eq(expected_nil_coercion)
      end
    end

    context "when value is already correct type" do
      let(:value) { correct_type_value }

      it "returns the value unchanged" do
        expect(coercion).to eq(correct_type_value)
      end
    end

    context "when value needs coercion" do
      let(:value) { coercible_value }

      it "returns correctly coerced value" do
        expect(coercion).to eq(expected_coerced_value)
      end
    end
  end
end

RSpec.shared_examples "a coercion that raises on nil" do
  describe ".call" do
    context "when value is nil" do
      let(:value) { nil }

      it "raises CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, expected_nil_error_message)
      end
    end

    context "when value is already correct type" do
      let(:value) { correct_type_value }

      it "returns the value unchanged" do
        expect(coercion).to eq(correct_type_value)
      end
    end

    context "when value needs coercion" do
      let(:value) { coercible_value }

      it "returns correctly coerced value" do
        expect(coercion).to eq(expected_coerced_value)
      end
    end

    context "when value is invalid for coercion" do
      let(:value) { invalid_coercible_value }

      it "raises CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, expected_invalid_error_message)
      end
    end
  end
end

RSpec.shared_examples "a coercion with options" do
  describe ".call" do
    let(:options) { {} }

    context "when value is nil" do
      let(:value) { nil }

      it "raises CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, expected_nil_error_message)
      end
    end

    context "when value is already correct type" do
      let(:value) { correct_type_value }

      it "returns the value unchanged" do
        expect(coercion).to be_a(expected_type_class)
      end
    end

    context "when value is invalid for coercion" do
      let(:value) { invalid_coercible_value }

      it "raises CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, expected_invalid_error_message)
      end
    end

    context "when using format options" do
      let(:options) { format_options }
      let(:value) { formatted_input_value }

      it "returns correctly coerced value with format" do
        expect(coercion).to be_a(expected_type_class)
      end

      context "with invalid format input" do
        let(:value) { invalid_format_input }

        it "raises CoercionError" do
          expect { coercion }.to raise_error(CMDx::CoercionError, expected_invalid_error_message)
        end
      end
    end
  end
end

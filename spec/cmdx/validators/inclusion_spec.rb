# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  describe "#call" do
    context "with array inclusion" do
      it "passes when value is in the array" do
        expect { described_class.call("active", inclusion: { in: %w[active pending] }) }.not_to raise_error
      end

      it "passes when numeric value is in the array" do
        expect { described_class.call(2, inclusion: { in: [1, 2, 3] }) }.not_to raise_error
      end

      it "passes when boolean value is in the array" do
        expect { described_class.call(true, inclusion: { in: [true, false] }) }.not_to raise_error
      end

      it "passes when nil value is in the array" do
        expect { described_class.call(nil, inclusion: { in: [nil, "value"] }) }.not_to raise_error
      end

      it "raises ValidationError when value is not in the array" do
        expect do
          described_class.call("cancelled", inclusion: { in: %w[active pending] })
        end.to raise_error(CMDx::ValidationError, 'must be one of: "active", "pending"')
      end

      it "raises ValidationError when numeric value is not in the array" do
        expect do
          described_class.call(5, inclusion: { in: [1, 2, 3] })
        end.to raise_error(CMDx::ValidationError, "must be one of: 1, 2, 3")
      end

      it "raises ValidationError when boolean value is not in the array" do
        expect do
          described_class.call(false, inclusion: { in: [true] })
        end.to raise_error(CMDx::ValidationError, "must be one of: true")
      end
    end

    context "with within alias" do
      it "passes when value is within the array" do
        expect { described_class.call("test", inclusion: { within: %w[test value] }) }.not_to raise_error
      end

      it "raises ValidationError when value is not within the array" do
        expect do
          described_class.call("other", inclusion: { within: %w[test value] })
        end.to raise_error(CMDx::ValidationError, 'must be one of: "test", "value"')
      end
    end

    context "with range inclusion" do
      it "passes when numeric value is in the range" do
        expect { described_class.call(25, inclusion: { in: 18..65 }) }.not_to raise_error
      end

      it "passes when value is at range boundary" do
        expect { described_class.call(18, inclusion: { in: 18..65 }) }.not_to raise_error
        expect { described_class.call(65, inclusion: { in: 18..65 }) }.not_to raise_error
      end

      it "passes when float value is in the range" do
        expect { described_class.call(2.5, inclusion: { in: 1.0..5.0 }) }.not_to raise_error
      end

      it "raises ValidationError when value is below range" do
        expect do
          described_class.call(15, inclusion: { in: 18..65 })
        end.to raise_error(CMDx::ValidationError, "must be within 18 and 65")
      end

      it "raises ValidationError when value is above range" do
        expect do
          described_class.call(70, inclusion: { in: 18..65 })
        end.to raise_error(CMDx::ValidationError, "must be within 18 and 65")
      end

      it "handles exclusive ranges" do
        expect { described_class.call(5, inclusion: { in: 1...10 }) }.not_to raise_error
      end

      it "raises ValidationError for exclusive range boundary" do
        expect do
          described_class.call(10, inclusion: { in: 1...10 })
        end.to raise_error(CMDx::ValidationError, "must be within 1 and 10")
      end
    end

    context "with within range alias" do
      it "passes when value is within the range" do
        expect { described_class.call(30, inclusion: { within: 20..40 }) }.not_to raise_error
      end

      it "raises ValidationError when value is not within the range" do
        expect do
          described_class.call(50, inclusion: { within: 20..40 })
        end.to raise_error(CMDx::ValidationError, "must be within 20 and 40")
      end
    end

    context "with custom error messages" do
      it "uses custom of_message for array inclusion" do
        expect do
          described_class.call("invalid", inclusion: {
                                 in: %w[valid pending],
                                 of_message: "status must be valid or pending"
                               })
        end.to raise_error(CMDx::ValidationError, "status must be valid or pending")
      end

      it "uses custom in_message for range inclusion" do
        expect do
          described_class.call(15, inclusion: {
                                 in: 18..65,
                                 in_message: "age must be between %{min} and %{max} years"
                               })
        end.to raise_error(CMDx::ValidationError, "age must be between 18 and 65 years")
      end

      it "uses custom within_message for range inclusion" do
        expect do
          described_class.call(100, inclusion: {
                                 within: 0..50,
                                 within_message: "score must be from %{min} to %{max}"
                               })
        end.to raise_error(CMDx::ValidationError, "score must be from 0 to 50")
      end

      it "uses general message override for array" do
        expect do
          described_class.call("bad", inclusion: {
                                 in: ["good"],
                                 message: "general error message"
                               })
        end.to raise_error(CMDx::ValidationError, "general error message")
      end

      it "uses general message override for range" do
        expect do
          described_class.call(100, inclusion: {
                                 in: 1..50,
                                 message: "general range error"
                               })
        end.to raise_error(CMDx::ValidationError, "general range error")
      end

      it "uses I18n translation for array when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.inclusion.of", values: '"test"', default: 'must be one of: "test"').and_return("translated array error")

        expect do
          described_class.call("invalid", inclusion: { in: ["test"] })
        end.to raise_error(CMDx::ValidationError, "translated array error")
      end

      it "uses I18n translation for range when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.inclusion.within", min: 1, max: 10, default: "must be within 1 and 10").and_return("translated range error")

        expect do
          described_class.call(15, inclusion: { in: 1..10 })
        end.to raise_error(CMDx::ValidationError, "translated range error")
      end
    end

    context "with different value types" do
      it "validates string values" do
        expect { described_class.call("admin", inclusion: { in: %w[admin user] }) }.not_to raise_error
      end

      it "validates symbol values" do
        expect { described_class.call(:active, inclusion: { in: %i[active pending] }) }.not_to raise_error
      end

      it "validates integer values" do
        expect { described_class.call(42, inclusion: { in: [1, 42, 100] }) }.not_to raise_error
      end

      it "validates float values" do
        expect { described_class.call(3.14, inclusion: { in: [1.0, 3.14, 5.0] }) }.not_to raise_error
      end

      it "validates object values" do
        obj = Object.new
        expect { described_class.call(obj, inclusion: { in: [obj, "other"] }) }.not_to raise_error
      end

      it "validates class values" do
        expect { described_class.call("string", inclusion: { in: [String, Integer] }) }.not_to raise_error
      end
    end

    context "with case equality matching" do
      it "matches using case equality operator" do
        expect { described_class.call("test", inclusion: { in: [/test/] }) }.not_to raise_error
      end

      it "matches class instances" do
        expect { described_class.call("string", inclusion: { in: [String] }) }.not_to raise_error
      end

      it "matches proc conditions" do
        condition = ->(x) { x > 10 }
        expect { described_class.call(15, inclusion: { in: [condition] }) }.not_to raise_error
      end

      it "fails when case equality does not match" do
        expect do
          described_class.call("no match", inclusion: { in: [/test/] })
        end.to raise_error(CMDx::ValidationError)
      end
    end

    context "with edge cases" do
      it "handles empty array" do
        expect do
          described_class.call("test", inclusion: { in: [] })
        end.to raise_error(CMDx::ValidationError, "must be one of: ")
      end

      it "handles single value array" do
        expect { described_class.call("only", inclusion: { in: ["only"] }) }.not_to raise_error
      end

      it "handles mixed type arrays" do
        expect { described_class.call(1, inclusion: { in: [1, "string", :symbol, nil] }) }.not_to raise_error
      end

      it "handles negative ranges" do
        expect { described_class.call(-5, inclusion: { in: -10..-1 }) }.not_to raise_error
      end

      it "handles character ranges" do
        expect { described_class.call("m", inclusion: { in: "a".."z" }) }.not_to raise_error
      end

      it "handles date ranges" do
        date = Date.new(2023, 6, 15)
        range = Date.new(2023, 1, 1)..Date.new(2023, 12, 31)
        expect { described_class.call(date, inclusion: { in: range }) }.not_to raise_error
      end
    end
  end
end

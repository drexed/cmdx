# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  describe "#call" do
    context "with array exclusion" do
      it "passes when value is not in the array" do
        expect { described_class.call("pending", exclusion: { in: %w[cancelled failed] }) }.not_to raise_error
      end

      it "passes when numeric value is not in the array" do
        expect { described_class.call(5, exclusion: { in: [1, 2, 3] }) }.not_to raise_error
      end

      it "passes when boolean value is not in the array" do
        expect { described_class.call(false, exclusion: { in: [true] }) }.not_to raise_error
      end

      it "passes when nil value is not in the array" do
        expect { described_class.call(nil, exclusion: { in: %w[value other] }) }.not_to raise_error
      end

      it "raises ValidationError when value is in the array" do
        expect do
          described_class.call("cancelled", exclusion: { in: %w[cancelled failed] })
        end.to raise_error(CMDx::ValidationError, 'must not be one of: "cancelled", "failed"')
      end

      it "raises ValidationError when numeric value is in the array" do
        expect do
          described_class.call(2, exclusion: { in: [1, 2, 3] })
        end.to raise_error(CMDx::ValidationError, "must not be one of: 1, 2, 3")
      end

      it "raises ValidationError when boolean value is in the array" do
        expect do
          described_class.call(true, exclusion: { in: [true, false] })
        end.to raise_error(CMDx::ValidationError, "must not be one of: true, false")
      end
    end

    context "with within alias" do
      it "passes when value is not within the array" do
        expect { described_class.call("allowed", exclusion: { within: %w[forbidden banned] }) }.not_to raise_error
      end

      it "raises ValidationError when value is within the array" do
        expect do
          described_class.call("forbidden", exclusion: { within: %w[forbidden banned] })
        end.to raise_error(CMDx::ValidationError, 'must not be one of: "forbidden", "banned"')
      end
    end

    context "with range exclusion" do
      it "passes when numeric value is not in the range" do
        expect { described_class.call(25, exclusion: { in: 0..17 }) }.not_to raise_error
      end

      it "passes when value is outside range boundaries" do
        expect { described_class.call(17, exclusion: { in: 18..65 }) }.not_to raise_error
        expect { described_class.call(66, exclusion: { in: 18..65 }) }.not_to raise_error
      end

      it "passes when float value is not in the range" do
        expect { described_class.call(0.5, exclusion: { in: 1.0..5.0 }) }.not_to raise_error
      end

      it "raises ValidationError when value is in range" do
        expect do
          described_class.call(15, exclusion: { in: 0..17 })
        end.to raise_error(CMDx::ValidationError, "must not be within 0 and 17")
      end

      it "raises ValidationError when value is at range boundary" do
        expect do
          described_class.call(18, exclusion: { in: 18..65 })
        end.to raise_error(CMDx::ValidationError, "must not be within 18 and 65")
      end

      it "handles exclusive ranges" do
        expect { described_class.call(10, exclusion: { in: 1...10 }) }.not_to raise_error
      end

      it "raises ValidationError for value in exclusive range" do
        expect do
          described_class.call(5, exclusion: { in: 1...10 })
        end.to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
      end
    end

    context "with within range alias" do
      it "passes when value is not within the range" do
        expect { described_class.call(50, exclusion: { within: 20..40 }) }.not_to raise_error
      end

      it "raises ValidationError when value is within the range" do
        expect do
          described_class.call(30, exclusion: { within: 20..40 })
        end.to raise_error(CMDx::ValidationError, "must not be within 20 and 40")
      end
    end

    context "with custom error messages" do
      it "uses custom of_message for array exclusion" do
        expect do
          described_class.call("admin", exclusion: {
                                 in: %w[admin root],
                                 of_message: "role is restricted"
                               })
        end.to raise_error(CMDx::ValidationError, "role is restricted")
      end

      it "uses custom in_message for range exclusion" do
        expect do
          described_class.call(15, exclusion: {
                                 in: 0..17,
                                 in_message: "age must be %{min} or older"
                               })
        end.to raise_error(CMDx::ValidationError, "age must be 0 or older")
      end

      it "uses custom within_message for range exclusion" do
        expect do
          described_class.call(95, exclusion: {
                                 within: 90..100,
                                 within_message: "score cannot be in top %{min}-%{max} range"
                               })
        end.to raise_error(CMDx::ValidationError, "score cannot be in top 90-100 range")
      end

      it "uses general message override for array" do
        expect do
          described_class.call("bad", exclusion: {
                                 in: ["bad"],
                                 message: "general error message"
                               })
        end.to raise_error(CMDx::ValidationError, "general error message")
      end

      it "uses general message override for range" do
        expect do
          described_class.call(25, exclusion: {
                                 in: 20..30,
                                 message: "general range error"
                               })
        end.to raise_error(CMDx::ValidationError, "general range error")
      end

      it "uses I18n translation for array when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.exclusion.of", values: '"test"', default: 'must not be one of: "test"').and_return("translated array error")

        expect do
          described_class.call("test", exclusion: { in: ["test"] })
        end.to raise_error(CMDx::ValidationError, "translated array error")
      end

      it "uses I18n translation for range when available" do
        allow(I18n).to receive(:t).with("cmdx.validators.exclusion.within", min: 1, max: 10, default: "must not be within 1 and 10").and_return("translated range error")

        expect do
          described_class.call(5, exclusion: { in: 1..10 })
        end.to raise_error(CMDx::ValidationError, "translated range error")
      end
    end

    context "with different value types" do
      it "validates string values" do
        expect { described_class.call("user", exclusion: { in: %w[admin root] }) }.not_to raise_error
      end

      it "validates symbol values" do
        expect { described_class.call(:pending, exclusion: { in: %i[cancelled failed] }) }.not_to raise_error
      end

      it "validates integer values" do
        expect { described_class.call(50, exclusion: { in: [1, 10, 25] }) }.not_to raise_error
      end

      it "validates float values" do
        expect { described_class.call(7.5, exclusion: { in: [1.0, 3.14, 5.0] }) }.not_to raise_error
      end

      it "validates object values" do
        obj1 = Object.new
        obj2 = Object.new
        expect { described_class.call(obj1, exclusion: { in: [obj2, "other"] }) }.not_to raise_error
      end

      it "validates class values" do
        expect { described_class.call(Float, exclusion: { in: [String, Integer] }) }.not_to raise_error
      end
    end

    context "with case equality matching" do
      it "passes when case equality does not match" do
        expect { described_class.call("no match", exclusion: { in: [/test/] }) }.not_to raise_error
      end

      it "passes when class instance does not match" do
        expect { described_class.call(42, exclusion: { in: [String] }) }.not_to raise_error
      end

      it "passes when proc condition does not match" do
        condition = ->(x) { x > 10 }
        expect { described_class.call(5, exclusion: { in: [condition] }) }.not_to raise_error
      end

      it "raises ValidationError when case equality matches" do
        expect do
          described_class.call("test", exclusion: { in: [/test/] })
        end.to raise_error(CMDx::ValidationError)
      end

      it "raises ValidationError when class matches" do
        expect do
          described_class.call("string", exclusion: { in: [String] })
        end.to raise_error(CMDx::ValidationError)
      end

      it "raises ValidationError when proc condition matches" do
        condition = ->(x) { x > 10 }
        expect do
          described_class.call(15, exclusion: { in: [condition] })
        end.to raise_error(CMDx::ValidationError)
      end
    end

    context "with edge cases" do
      it "passes when empty array is excluded" do
        expect { described_class.call("test", exclusion: { in: [] }) }.not_to raise_error
      end

      it "raises ValidationError with single value array" do
        expect do
          described_class.call("only", exclusion: { in: ["only"] })
        end.to raise_error(CMDx::ValidationError, 'must not be one of: "only"')
      end

      it "handles mixed type arrays" do
        expect { described_class.call("string", exclusion: { in: [1, :symbol, nil] }) }.not_to raise_error
      end

      it "handles negative ranges" do
        expect { described_class.call(5, exclusion: { in: -10..-1 }) }.not_to raise_error
      end

      it "handles character ranges" do
        expect { described_class.call("z", exclusion: { in: "a".."m" }) }.not_to raise_error
      end

      it "handles date ranges" do
        date = Date.new(2024, 6, 15)
        range = Date.new(2023, 1, 1)..Date.new(2023, 12, 31)
        expect { described_class.call(date, exclusion: { in: range }) }.not_to raise_error
      end

      it "handles nil values in exclusion" do
        expect { described_class.call("value", exclusion: { in: [nil] }) }.not_to raise_error
      end

      it "raises ValidationError when nil is excluded" do
        expect do
          described_class.call(nil, exclusion: { in: [nil, "other"] })
        end.to raise_error(CMDx::ValidationError)
      end
    end

    context "with no exclusion values" do
      it "passes when no values to exclude" do
        expect { described_class.call("anything", exclusion: { in: nil }) }.not_to raise_error
      end

      it "passes when exclusion array is nil" do
        expect { described_class.call(42, exclusion: { within: nil }) }.not_to raise_error
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::DateTime do
  describe "#call" do
    context "with DateTime values" do
      it "returns DateTime unchanged" do
        datetime = DateTime.new(2023, 12, 25, 10, 30, 45)
        expect(described_class.call(datetime)).to eq(datetime)
      end

      it "returns current datetime unchanged" do
        datetime = DateTime.now
        expect(described_class.call(datetime)).to eq(datetime)
      end
    end

    context "with Date values" do
      it "returns Date unchanged" do
        date = Date.new(2023, 12, 25)
        expect(described_class.call(date)).to eq(date)
      end
    end

    context "with Time values" do
      it "returns Time unchanged" do
        time = Time.new(2023, 12, 25, 10, 30, 45)
        expect(described_class.call(time)).to eq(time)
      end
    end

    context "with string values using standard format" do
      it "parses ISO 8601 datetime string" do
        result = described_class.call("2023-12-25T10:30:45")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(10)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(45)
      end

      it "parses date string without time" do
        result = described_class.call("2023-12-25")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses datetime with timezone" do
        result = described_class.call("2023-12-25 10:30:45 UTC")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses RFC 2822 format" do
        result = described_class.call("Mon, 25 Dec 2023 10:30:45 +0000")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError for invalid datetime string" do
        expect do
          described_class.call("invalid datetime")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with custom format option" do
      it "parses datetime with custom format" do
        result = described_class.call("25/12/2023 14:30", format: "%d/%m/%Y %H:%M")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses datetime with different custom format" do
        result = described_class.call("2023-12-25 10:30:45", format: "%Y-%m-%d %H:%M:%S")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(10)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(45)
      end

      it "raises CoercionError for mismatched format" do
        expect do
          described_class.call("25/12/2023", format: "%Y-%m-%d")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for invalid format string" do
        expect do
          described_class.call("2023-12-25", format: "invalid format")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with numeric values" do
      it "raises CoercionError for integer" do
        expect do
          described_class.call(1_703_505_045)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for float" do
        expect do
          described_class.call(1_703_505_045.123)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([2023, 12, 25, 10, 30, 45])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ year: 2023, month: 12, day: 25 })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:now)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "datetime", default: "could not coerce into a datetime").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles midnight datetime" do
        result = described_class.call("2023-12-25 00:00:00")
        expect(result).to be_a(DateTime)
        expect(result.hour).to eq(0)
        expect(result.min).to eq(0)
        expect(result.sec).to eq(0)
      end

      it "handles end of day datetime" do
        result = described_class.call("2023-12-25 23:59:59")
        expect(result).to be_a(DateTime)
        expect(result.hour).to eq(23)
        expect(result.min).to eq(59)
        expect(result.sec).to eq(59)
      end

      it "handles leap year datetime" do
        result = described_class.call("2024-02-29 12:00:00")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2024)
        expect(result.month).to eq(2)
        expect(result.day).to eq(29)
      end

      it "raises CoercionError for invalid leap year datetime" do
        expect do
          described_class.call("2023-02-29 12:00:00")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a datetime/)
      end

      it "handles datetime with milliseconds" do
        result = described_class.call("2023-12-25T10:30:45.123Z")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "handles datetime with timezone offset" do
        result = described_class.call("2023-12-25T10:30:45+05:30")
        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end
  end
end

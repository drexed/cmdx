# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Date do
  describe "#call" do
    context "with Date values" do
      it "returns Date unchanged" do
        date = Date.new(2023, 12, 25)
        expect(described_class.call(date)).to eq(date)
      end

      it "returns Date unchanged for current date" do
        date = Date.today
        expect(described_class.call(date)).to eq(date)
      end
    end

    context "with DateTime values" do
      it "returns DateTime unchanged" do
        datetime = DateTime.new(2023, 12, 25, 10, 30, 45)
        expect(described_class.call(datetime)).to eq(datetime)
      end
    end

    context "with Time values" do
      it "returns Time unchanged" do
        time = Time.new(2023, 12, 25, 10, 30, 45)
        expect(described_class.call(time)).to eq(time)
      end
    end

    context "with string values using standard format" do
      it "parses ISO 8601 date string" do
        result = described_class.call("2023-12-25")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError for US format date string" do
        expect do
          described_class.call("12/25/2023")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "parses European format date string" do
        result = described_class.call("25/12/2023")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with month name" do
        result = described_class.call("December 25, 2023")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError for invalid date string" do
        expect do
          described_class.call("invalid date")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with custom format option" do
      it "parses date with custom format" do
        result = described_class.call("25/12/2023", format: "%d/%m/%Y")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with different custom format" do
        result = described_class.call("2023-12-25", format: "%Y-%m-%d")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with time format" do
        result = described_class.call("25/12/2023 14:30", format: "%d/%m/%Y %H:%M")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError for mismatched format" do
        expect do
          described_class.call("25/12/2023", format: "%Y-%m-%d")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for invalid format string" do
        expect do
          described_class.call("2023-12-25", format: "invalid format")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with numeric values" do
      it "raises CoercionError for integer" do
        expect do
          described_class.call(20_231_225)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for float" do
        expect do
          described_class.call(2023.1225)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([2023, 12, 25])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ year: 2023, month: 12, day: 25 })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:today)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "date", default: "could not coerce into a date").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles leap year dates" do
        result = described_class.call("2024-02-29")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2024)
        expect(result.month).to eq(2)
        expect(result.day).to eq(29)
      end

      it "handles first day of year" do
        result = described_class.call("2023-01-01")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(1)
        expect(result.day).to eq(1)
      end

      it "handles last day of year" do
        result = described_class.call("2023-12-31")
        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(31)
      end

      it "raises CoercionError for invalid leap year date" do
        expect do
          described_class.call("2023-02-29")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a date/)
      end
    end
  end
end

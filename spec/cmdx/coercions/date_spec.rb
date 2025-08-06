# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Date do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is already an analog type" do
      it "returns Date unchanged" do
        date = Date.new(2023, 12, 25)
        result = coercion.call(date)

        expect(result).to eq(date)
      end

      it "returns DateTime unchanged" do
        datetime = DateTime.new(2023, 12, 25, 14, 30, 0)
        result = coercion.call(datetime)

        expect(result).to eq(datetime)
      end

      it "returns Time unchanged" do
        time = Time.new(2023, 12, 25, 14, 30, 0)
        result = coercion.call(time)

        expect(result).to eq(time)
      end
    end

    context "when value is a parseable string" do
      it "parses ISO 8601 date string" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses YYYY/MM/DD format date string" do
        result = coercion.call("2023/12/25")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses DD/MM/YYYY format date string" do
        result = coercion.call("25/12/2023")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with dashes" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses DD.MM.YYYY format date string" do
        result = coercion.call("25.12.2023")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses textual date format" do
        result = coercion.call("Dec 25, 2023")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with time component, extracting date part" do
        result = coercion.call("2023-12-25 14:30:00")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end

    context "with strptime option" do
      it "parses date using custom format" do
        result = coercion.call("25-Dec-2023", strptime: "%d-%b-%Y")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date using different custom format" do
        result = coercion.call("2023/12/25", strptime: "%Y/%m/%d")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses date with year first format" do
        result = coercion.call("23-12-25", strptime: "%y-%m-%d")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError when string doesn't match strptime format" do
        expect { coercion.call("invalid-date", strptime: "%Y-%m-%d") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end
    end

    context "when value cannot be coerced" do
      it "raises CoercionError for invalid date string" do
        expect { coercion.call("not-a-date") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for integer" do
        expect { coercion.call(123) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(12.3) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for boolean" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([2023, 12, 25]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ year: 2023, month: 12, day: 25 }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:date) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for invalid date components" do
        expect { coercion.call("2023-13-45") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for US format date string" do
        expect { coercion.call("12/25/2023") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for malformed date string" do
        expect { coercion.call("2023/25/12/extra") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "raises CoercionError for partially valid date string" do
        expect { coercion.call("2023-12") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end
    end

    context "with edge cases" do
      it "handles leap year date" do
        result = coercion.call("2024-02-29")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2024)
        expect(result.month).to eq(2)
        expect(result.day).to eq(29)
      end

      it "raises CoercionError for invalid leap year date" do
        expect { coercion.call("2023-02-29") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end

      it "handles end of year date" do
        result = coercion.call("2023-12-31")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(31)
      end

      it "handles start of year date" do
        result = coercion.call("2023-01-01")

        expect(result).to be_a(Date)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(1)
        expect(result.day).to eq(1)
      end
    end
  end
end

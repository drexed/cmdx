# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::DateTime, type: :unit do
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
      it "parses ISO 8601 datetime string" do
        result = coercion.call("2023-12-25T14:30:00")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.minute).to eq(30)
        expect(result.second).to eq(0)
      end

      it "parses date string" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses datetime with timezone" do
        result = coercion.call("2023-12-25T14:30:00+02:00")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.minute).to eq(30)
        expect(result.offset).to eq(Rational(2, 24))
      end

      it "parses slash format date" do
        result = coercion.call("2023/12/25")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses natural language date" do
        result = coercion.call("December 25, 2023")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end

    context "with strptime option" do
      it "parses string using custom format" do
        result = coercion.call("25-12-2023 14:30", strptime: "%d-%m-%Y %H:%M")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.minute).to eq(30)
      end

      it "parses date-only string with custom format" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises error when string doesn't match strptime format" do
        expect { coercion.call("2023-12-25", strptime: "%d/%m/%Y") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for invalid date string" do
        expect { coercion.call("invalid-date") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for integer" do
        expect { coercion.call(123) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(12.34) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for boolean" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([2023, 12, 25]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ year: 2023, month: 12, day: 25 }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:datetime) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for invalid date components" do
        expect { coercion.call("2023-13-32") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end

      it "raises CoercionError for malformed datetime string" do
        expect { coercion.call("2023/12/25T25:61:70") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a date time")
      end
    end
  end
end

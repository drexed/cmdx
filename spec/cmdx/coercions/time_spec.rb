# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Time do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is already an analog type" do
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

    context "when value responds to to_time" do
      it "calls to_time on the value" do
        date = Date.new(2023, 12, 25)

        result = coercion.call(date)

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "returns the to_time result" do
        time_result = Time.new(2023, 1, 1)
        value = instance_double("Time", to_time: time_result)

        result = coercion.call(value)

        expect(result).to eq(time_result)
      end
    end

    context "with strptime option" do
      it "parses string using custom format" do
        result = coercion.call("25-12-2023 14:30", strptime: "%d-%m-%Y %H:%M")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses date string with custom format" do
        result = coercion.call("2023/12/25", strptime: "%Y/%m/%d")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "raises CoercionError when string doesn't match strptime format" do
        expect { coercion.call("2023-12-25", strptime: "%d/%m/%Y") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for invalid date with strptime" do
        expect { coercion.call("32/13/2023", strptime: "%d/%m/%Y") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end
    end

    context "when value is a parseable string" do
      it "parses ISO 8601 time string" do
        result = coercion.call("2023-12-25T14:30:00")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(0)
      end

      it "parses date string" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses time string" do
        result = coercion.call("14:30:00")

        expect(result).to be_a(Time)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(0)
      end

      it "parses RFC 2822 formatted string" do
        result = coercion.call("Mon, 25 Dec 2023 14:30:00 +0000")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses human-readable date string" do
        result = coercion.call("December 25, 2023")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end

    context "when value cannot be coerced" do
      it "raises CoercionError for invalid string" do
        expect { coercion.call("invalid-time") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for integer" do
        expect { coercion.call(123) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(123.45) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for boolean true" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for boolean false" do
        expect { coercion.call(false) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ year: 2023 }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:time) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError for object" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError when Time.parse raises ArgumentError" do
        allow(Time).to receive(:parse).and_raise(ArgumentError)

        expect { coercion.call("some-string") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end

      it "raises CoercionError when Time.parse raises TypeError" do
        allow(Time).to receive(:parse).and_raise(TypeError)

        expect { coercion.call("some-string") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end
    end

    context "without options" do
      it "calls Time.parse when no options provided" do
        time_string = "2023-12-25T14:30:00"
        parsed_time = Time.new(2023, 12, 25, 14, 30, 0)

        allow(Time).to receive(:parse).with(time_string).and_return(parsed_time)

        result = coercion.call(time_string)

        expect(Time).to have_received(:parse).with(time_string)
        expect(result).to eq(parsed_time)
      end

      it "does not call Time.strptime when no strptime option" do
        allow(Time).to receive(:strptime)

        coercion.call("2023-12-25")

        expect(Time).not_to have_received(:strptime)
      end
    end
  end
end

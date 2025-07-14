# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Date do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("2023-12-25")).to eq(Date.parse("2023-12-25"))
    end
  end

  describe "#call" do
    context "with date-like objects" do
      it "returns Date objects unchanged" do
        input = Date.new(2023, 12, 25)
        result = coercion.call(input)

        expect(result).to eq(input)
        expect(result).to be_a(Date)
      end

      it "returns DateTime objects unchanged" do
        input = DateTime.new(2023, 12, 25, 10, 30, 45)
        result = coercion.call(input)

        expect(result).to eq(input)
        expect(result).to be_a(DateTime)
      end

      it "returns Time objects unchanged" do
        input = Time.new(2023, 12, 25, 10, 30, 45)
        result = coercion.call(input)

        expect(result).to eq(input)
        expect(result).to be_a(Time)
      end
    end

    context "with string values and default parsing" do
      it "parses ISO 8601 date strings" do
        result = coercion.call("2023-12-25")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses US format date strings" do
        result = coercion.call("Dec 25 2023")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses European format date strings" do
        result = coercion.call("25-12-2023")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses date strings with month names" do
        result = coercion.call("December 25, 2023")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses abbreviated month names" do
        result = coercion.call("Dec 25, 2023")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses date strings with time components" do
        result = coercion.call("2023-12-25 10:30:45")

        expect(result).to eq(Date.new(2023, 12, 25))
      end
    end

    context "with custom strptime format" do
      it "parses dates with custom format" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses dates with different custom format" do
        result = coercion.call("2023.12.25", strptime: "%Y.%m.%d")

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "parses dates with time in custom format" do
        result = coercion.call("25-12-2023 14:30", strptime: "%d-%m-%Y %H:%M")

        expect(result).to eq(Date.new(2023, 12, 25))
      end
    end

    context "with invalid values" do
      it "raises CoercionError for invalid date strings" do
        expect { coercion.call("invalid date") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for numeric values" do
        expect { coercion.call(123) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for nil values" do
        expect { coercion.call(nil) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for arrays" do
        expect { coercion.call([]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError for hashes" do
        expect { coercion.call({}) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end

      it "raises CoercionError when strptime format doesn't match" do
        expect { coercion.call("2023-12-25", strptime: "%d/%m/%Y") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a date/
        )
      end
    end

    context "with edge cases" do
      it "handles leap year dates" do
        result = coercion.call("2020-02-29")

        expect(result).to eq(Date.new(2020, 2, 29))
      end

      it "handles dates at year boundaries" do
        result = coercion.call("2023-01-01")

        expect(result).to eq(Date.new(2023, 1, 1))
      end

      it "handles end of year dates" do
        result = coercion.call("2023-12-31")

        expect(result).to eq(Date.new(2023, 12, 31))
      end

      it "handles dates with extra whitespace" do
        result = coercion.call("  2023-12-25  ")

        expect(result).to eq(Date.new(2023, 12, 25))
      end
    end

    context "with options parameter" do
      it "ignores unknown options" do
        result = coercion.call("2023-12-25", { unknown: "option" })

        expect(result).to eq(Date.new(2023, 12, 25))
      end

      it "processes strptime option alongside other options" do
        result = coercion.call("25/12/2023", { strptime: "%d/%m/%Y", other: "option" })

        expect(result).to eq(Date.new(2023, 12, 25))
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessDateTask") do
        required :start_date, type: :date
        optional :end_date, type: :date, default: -> { Date.today }

        def call
          context.date_range = (start_date..end_date)
          context.days_count = (end_date - start_date).to_i
        end
      end
    end

    it "coerces string parameters to Date objects" do
      result = task_class.call(start_date: "2023-12-01", end_date: "2023-12-25")

      expect(result).to be_success
      expect(result.context.date_range).to eq(Date.new(2023, 12, 1)..Date.new(2023, 12, 25))
      expect(result.context.days_count).to eq(24)
    end

    it "handles Date objects unchanged" do
      start_date = Date.new(2023, 12, 1)
      end_date = Date.new(2023, 12, 25)
      result = task_class.call(start_date: start_date, end_date: end_date)

      expect(result).to be_success
      expect(result.context.date_range).to eq(start_date..end_date)
    end

    it "uses default values for optional date parameters" do
      result = task_class.call(start_date: "2023-12-01")

      expect(result).to be_success
      expect(result.context.date_range.begin).to eq(Date.new(2023, 12, 1))
      expect(result.context.date_range.end).to eq(Date.today)
    end

    it "fails when coercion fails for invalid dates" do
      result = task_class.call(start_date: "invalid date")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a date")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::DateTime do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("2023-12-25")).to be_a(DateTime)
    end
  end

  describe "#call" do
    context "with analog types" do
      it "returns DateTime objects unchanged" do
        dt = DateTime.new(2023, 12, 25)
        result = coercion.call(dt)

        expect(result).to eq(dt)
      end

      it "returns Date objects unchanged" do
        date = Date.new(2023, 12, 25)
        result = coercion.call(date)

        expect(result).to eq(date)
      end

      it "returns Time objects unchanged" do
        time = Time.new(2023, 12, 25, 10, 30, 45)
        result = coercion.call(time)

        expect(result).to eq(time)
      end
    end

    context "with string values and default parsing" do
      it "parses ISO 8601 date strings" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses ISO 8601 datetime strings" do
        result = coercion.call("2023-12-25T14:30:45")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.minute).to eq(30)
        expect(result.second).to eq(45)
      end

      it "parses datetime strings with timezone" do
        result = coercion.call("2023-12-25T14:30:45+05:00")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.offset).to eq(Rational(5, 24))
      end

      it "parses common date formats" do
        result = coercion.call("December 25, 2023")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses short date formats" do
        result = coercion.call("Dec 25 2023")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end

    context "with custom strptime format" do
      it "parses dates with custom format" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses datetime with custom format" do
        result = coercion.call("25-12-2023 14:30", strptime: "%d-%m-%Y %H:%M")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.minute).to eq(30)
      end

      it "raises CoercionError for invalid format" do
        expect { coercion.call("invalid", strptime: "%d/%m/%Y") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end
    end

    context "with invalid values" do
      it "raises CoercionError for invalid date strings" do
        expect { coercion.call("not a date") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for numeric values" do
        expect { coercion.call(123) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for nil values" do
        expect { coercion.call(nil) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for array values" do
        expect { coercion.call([]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end

      it "raises CoercionError for hash values" do
        expect { coercion.call({}) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a datetime/
        )
      end
    end

    context "with options parameter" do
      it "ignores unknown options" do
        result = coercion.call("2023-12-25", unknown: "option")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
      end

      it "processes strptime option correctly" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y", other: "ignored")

        expect(result).to be_a(DateTime)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessDateTask") do
        required :start_date, type: :datetime
        optional :end_date, type: :datetime, default: -> { DateTime.now }

        def call
          context.date_range = end_date - start_date
          context.formatted_start = start_date.strftime("%Y-%m-%d")
        end
      end
    end

    it "coerces date string parameters to DateTime" do
      result = task_class.call(start_date: "2023-12-25")

      expect(result).to be_success
      expect(result.context.formatted_start).to eq("2023-12-25")
    end

    it "handles DateTime parameters unchanged" do
      dt = DateTime.new(2023, 12, 25)
      result = task_class.call(start_date: dt)

      expect(result).to be_success
      expect(result.context.formatted_start).to eq("2023-12-25")
    end

    it "handles Date parameters unchanged" do
      date = Date.new(2023, 12, 25)
      result = task_class.call(start_date: date)

      expect(result).to be_success
      expect(result.context.formatted_start).to eq("2023-12-25")
    end

    it "uses default values for optional datetime parameters" do
      result = task_class.call(start_date: "2023-12-25")

      expect(result).to be_success
      expect(result.context.date_range).to be_a(Rational)
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(start_date: "2023-12-25", end_date: "2023-12-26")

      expect(result).to be_success
      expect(result.context.date_range).to eq(1)
    end

    it "fails when coercion fails for invalid dates" do
      result = task_class.call(start_date: "invalid date")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a datetime")
    end
  end

  describe "custom format integration" do
    let(:task_class) do
      create_simple_task(name: "CustomDateTask") do
        required :event_date, type: :datetime, strptime: "%d/%m/%Y"

        def call
          context.year = event_date.year
          context.month = event_date.month
        end
      end
    end

    it "uses custom strptime format from parameter definition" do
      result = task_class.call(event_date: "25/12/2023")

      expect(result).to be_success
      expect(result.context.year).to eq(2023)
      expect(result.context.month).to eq(12)
    end

    it "fails with invalid format for custom strptime" do
      result = task_class.call(event_date: "2023-12-25")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a datetime")
    end
  end
end

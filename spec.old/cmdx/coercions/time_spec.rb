# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Time do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("2023-12-25 14:30:00")).to be_a(Time)
    end
  end

  describe "#call" do
    context "with analog types" do
      it "returns Time objects unchanged" do
        time = Time.new(2023, 12, 25, 14, 30, 45)
        result = coercion.call(time)

        expect(result).to eq(time)
      end

      it "returns Date objects unchanged" do
        date = Date.new(2023, 12, 25)
        result = coercion.call(date)

        expect(result).to eq(date.to_time)
      end

      it "returns DateTime objects unchanged" do
        dt = DateTime.new(2023, 12, 25, 14, 30, 45)
        result = coercion.call(dt)

        expect(result).to eq(dt)
      end
    end

    context "with string values and default parsing" do
      it "parses ISO 8601 datetime strings" do
        result = coercion.call("2023-12-25 14:30:45")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(45)
      end

      it "parses time strings with timezone" do
        result = coercion.call("2023-12-25 14:30:45 +0500")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.utc_offset).to eq(18_000) # 5 hours in seconds
      end

      it "parses common datetime formats" do
        result = coercion.call("December 25, 2023 14:30")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses date-only strings" do
        result = coercion.call("2023-12-25")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses short datetime formats" do
        result = coercion.call("Dec 25 2023 2:30 PM")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end
    end

    context "with custom strptime format" do
      it "parses dates with custom format" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end

      it "parses datetime with custom format" do
        result = coercion.call("25-12-2023 14:30", strptime: "%d-%m-%Y %H:%M")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
      end

      it "parses time with custom format" do
        result = coercion.call("14:30:45", strptime: "%H:%M:%S")

        expect(result).to be_a(Time)
        expect(result.hour).to eq(14)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(45)
      end

      it "raises CoercionError for invalid format" do
        expect { coercion.call("invalid", strptime: "%d/%m/%Y") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end
    end

    context "with invalid values" do
      it "raises CoercionError for invalid time strings" do
        expect { coercion.call("not a time") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for numeric values" do
        expect { coercion.call(123) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for nil values" do
        expect { coercion.call(nil) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for array values" do
        expect { coercion.call([]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end

      it "raises CoercionError for hash values" do
        expect { coercion.call({}) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a time/
        )
      end
    end

    context "with options parameter" do
      it "ignores unknown options" do
        result = coercion.call("2023-12-25 14:30:00", unknown: "option")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
      end

      it "processes strptime option correctly" do
        result = coercion.call("25/12/2023", strptime: "%d/%m/%Y", other: "ignored")

        expect(result).to be_a(Time)
        expect(result.year).to eq(2023)
        expect(result.month).to eq(12)
        expect(result.day).to eq(25)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessTimeTask") do
        required :start_time, type: :time
        optional :end_time, type: :time, default: -> { Time.now }

        def call
          context.duration = end_time - start_time
          context.formatted_start = start_time.strftime("%H:%M:%S")
        end
      end
    end

    it "coerces time string parameters to Time" do
      result = task_class.call(start_time: "2023-12-25 14:30:00")

      expect(result).to be_success
      expect(result.context.formatted_start).to eq("14:30:00")
    end

    it "handles Time parameters unchanged" do
      time = Time.new(2023, 12, 25, 14, 30, 45)
      result = task_class.call(start_time: time)

      expect(result).to be_success
      expect(result.context.formatted_start).to eq("14:30:45")
    end

    it "handles Date parameters unchanged" do
      date = Date.new(2023, 12, 25)
      result = task_class.call(start_time: date)

      expect(result).to be_success
      expect(result.context.duration).to be_a(Numeric)
    end

    it "uses default values for optional time parameters" do
      result = task_class.call(start_time: "2023-12-25 14:30:00")

      expect(result).to be_success
      expect(result.context.duration).to be_a(Numeric)
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(start_time: "2023-12-25 14:30:00", end_time: "2023-12-25 15:30:00")

      expect(result).to be_success
      expect(result.context.duration).to eq(3600) # 1 hour in seconds
    end

    it "fails when coercion fails for invalid times" do
      result = task_class.call(start_time: "invalid time")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a time")
    end
  end

  describe "custom format integration" do
    let(:task_class) do
      create_simple_task(name: "CustomTimeTask") do
        required :event_time, type: :time, strptime: "%d/%m/%Y %H:%M"

        def call
          context.hour = event_time.hour
          context.minute = event_time.min
        end
      end
    end

    it "uses custom strptime format from parameter definition" do
      result = task_class.call(event_time: "25/12/2023 14:30")

      expect(result).to be_success
      expect(result.context.hour).to eq(14)
      expect(result.context.minute).to eq(30)
    end

    it "fails with invalid format for custom strptime" do
      result = task_class.call(event_time: "2023-12-25 14:30")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a time")
    end
  end
end

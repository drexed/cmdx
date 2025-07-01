# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::LogTimestamp do
  describe ".call" do
    context "with valid time objects" do
      it "formats current time to ISO 8601 with microseconds" do
        time = Time.utc(2022, 7, 17, 18, 43, 15) + 0.123456

        result = described_class.call(time)

        expect(result).to match(/2022-07-17T18:43:15\.12345\d/)
      end

      it "formats UTC time correctly" do
        time = Time.utc(2023, 12, 25, 10, 30, 45) + 0.789012

        result = described_class.call(time)

        expect(result).to eq("2023-12-25T10:30:45.789012")
      end

      it "formats local time correctly" do
        time = Time.new(2024, 1, 1, 0, 0, 0, 0)

        result = described_class.call(time)

        expect(result).to eq("2024-01-01T00:00:00.000000")
      end

      it "handles time with fractional seconds" do
        time = Time.utc(2022, 6, 15, 14, 20, 30) + 0.5

        result = described_class.call(time)

        expect(result).to eq("2022-06-15T14:20:30.500000")
      end
    end

    context "with various time zones" do
      it "formats time in different timezone without timezone info" do
        time = Time.utc(2022, 8, 10, 16, 45, 30) + 0.25

        result = described_class.call(time)

        expect(result).to eq("2022-08-10T16:45:30.250000")
      end

      it "formats UTC time from different timezone" do
        local_time = Time.new(2022, 3, 15, 12, 0, 0, 0)
        utc_time = local_time.utc

        result = described_class.call(utc_time)

        expect(result).to match(/2022-03-\d{2}T\d{2}:00:00\.000000/)
      end

      it "maintains consistent format regardless of timezone" do
        utc_time = Time.utc(2022, 6, 1, 15, 30, 45, 0)
        local_time = utc_time.getlocal

        utc_result = described_class.call(utc_time)
        local_result = described_class.call(local_time)

        expect(utc_result).to match(/\d{4}-06-01T15:30:45\.000000/)
        expect(local_result).to match(/\d{4}-06-01T\d{2}:30:45\.000000/)
      end
    end

    context "with different time creation methods" do
      it "handles Time.at with integer" do
        time = Time.at(1_658_077_395)

        result = described_class.call(time)

        expect(result).to match(/2022-07-17T\d{2}:03:15\.000000/)
      end

      it "handles Time.now" do
        time = Time.now

        result = described_class.call(time)

        expect(result).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/)
      end

      it "handles Time.at with float" do
        time = Time.at(1_658_077_395.123456)

        result = described_class.call(time)

        expect(result).to match(/2022-07-17T\d{2}:03:15\.123456/)
      end

      it "handles Time.parse result" do
        time = Time.parse("2022-09-15 10:30:45 UTC")

        result = described_class.call(time)

        expect(result).to eq("2022-09-15T10:30:45.000000")
      end
    end

    context "with edge case times" do
      it "handles leap year February 29th" do
        time = Time.new(2020, 2, 29, 12, 0, 0, 0)

        result = described_class.call(time)

        expect(result).to eq("2020-02-29T12:00:00.000000")
      end

      it "handles end of year" do
        time = Time.utc(2022, 12, 31, 23, 59, 59) + 0.999999

        result = described_class.call(time)

        expect(result).to match(/2022-12-31T23:59:59\.99999\d/)
      end

      it "handles beginning of year" do
        time = Time.new(2023, 1, 1, 0, 0, 0, 0)

        result = described_class.call(time)

        expect(result).to eq("2023-01-01T00:00:00.000000")
      end

      it "handles maximum microsecond precision" do
        time = Time.utc(2022, 7, 4, 15, 30, 45) + 0.999999

        result = described_class.call(time)

        expect(result).to match(/2022-07-04T15:30:45\.99999\d/)
      end

      it "handles zero microseconds" do
        time = Time.new(2022, 5, 10, 8, 15, 30, 0)

        result = described_class.call(time)

        expect(result).to eq("2022-05-10T08:15:30.000000")
      end
    end

    context "format consistency" do
      it "always returns consistent date format" do
        time1 = Time.new(2022, 1, 1, 0, 0, 0, 0)
        time2 = Time.new(2022, 12, 31, 23, 59, 59, 0)

        result1 = described_class.call(time1)
        result2 = described_class.call(time2)

        expect(result1).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/)
        expect(result2).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/)
      end

      it "maintains format across different years" do
        time1 = Time.new(1999, 12, 31, 23, 59, 59, 0)
        time2 = Time.new(3000, 1, 1, 0, 0, 0, 0)

        result1 = described_class.call(time1)
        result2 = described_class.call(time2)

        expect(result1).to eq("1999-12-31T23:59:59.000000")
        expect(result2).to eq("3000-01-01T00:00:00.000000")
      end

      it "always returns 6-digit microsecond precision" do
        times = [
          Time.utc(2022, 1, 1, 0, 0, 0) + 0.123456,
          Time.utc(2022, 1, 1, 0, 0, 0) + 0.1,
          Time.new(2022, 1, 1, 0, 0, 0, 0)
        ]

        results = times.map { |time| described_class.call(time) }

        expect(results[0]).to match(/2022-01-01T00:00:00\.12345\d/)
        expect(results[1]).to eq("2022-01-01T00:00:00.100000")
        expect(results[2]).to eq("2022-01-01T00:00:00.000000")
      end
    end
  end
end

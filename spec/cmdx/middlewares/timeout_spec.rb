# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Timeout do
  describe "#initialize" do
    it "accepts a direct timeout value via hash" do
      middleware = described_class.new(seconds: 30)
      expect(middleware.seconds).to eq(30)
      expect(middleware.conditional).to eq({})
    end

    it "uses default timeout of 3 seconds when no value provided" do
      middleware = described_class.new
      expect(middleware.seconds).to eq(3)
      expect(middleware.conditional).to eq({})
    end

    it "accepts conditional options" do
      condition = proc { true }
      middleware = described_class.new(seconds: 30, if: condition, unless: :skip?)
      expect(middleware.seconds).to eq(30)
      expect(middleware.conditional).to eq(if: condition, unless: :skip?)
    end
  end

  describe "timeout behavior" do
    context "without conditions (always apply timeout)" do
      let(:task_class) do
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout, seconds: 1 # 1 second timeout

          def call
            sleep_duration = context.sleep_duration || 0.1
            sleep(sleep_duration)
            context.value = "completed"
          end
        end
      end

      it "allows task to complete within timeout" do
        result = task_class.call(sleep_duration: 0.1)
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end

      it "fails task that exceeds timeout" do
        result = task_class.call(sleep_duration: 2)
        expect(result).to be_failed
        expect(result.metadata).to include(
          reason: "[CMDx::TimeoutError] execution exceeded 1 seconds"
        )
      end
    end

    context "with conditional timeout (if condition)" do
      let(:task_class) do
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout,
              seconds: 1,
              if: proc { context.enable_timeout? }

          def call
            sleep_duration = context.sleep_duration || 0.1
            sleep(sleep_duration)
            context.value = "completed"
          end
        end
      end

      it "applies timeout when condition is true" do
        result = task_class.call(sleep_duration: 2, enable_timeout?: true)
        expect(result).to be_failed
        expect(result.metadata).to include(
          reason: "[CMDx::TimeoutError] execution exceeded 1 seconds"
        )
      end

      it "skips timeout when condition is false" do
        result = task_class.call(sleep_duration: 2, enable_timeout?: false)
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end

      it "skips timeout when condition is nil" do
        result = task_class.call(sleep_duration: 2, enable_timeout?: nil)
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end
    end

    context "with conditional timeout (unless condition)" do
      let(:task_class) do
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout,
              seconds: 1,
              unless: proc { context.skip_timeout? }

          def call
            sleep_duration = context.sleep_duration || 0.1
            sleep(sleep_duration)
            context.value = "completed"
          end
        end
      end

      it "applies timeout when condition is false" do
        result = task_class.call(sleep_duration: 2, skip_timeout?: false)
        expect(result).to be_failed
        expect(result.metadata).to include(
          reason: "[CMDx::TimeoutError] execution exceeded 1 seconds"
        )
      end

      it "skips timeout when condition is true" do
        result = task_class.call(sleep_duration: 2, skip_timeout?: true)
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end
    end

    context "with method-based conditions" do
      let(:task_class) do
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout,
              seconds: 1,
              unless: :development_mode?

          def call
            sleep_duration = context.sleep_duration || 0.1
            sleep(sleep_duration)
            context.value = "completed"
          end

          private

          def development_mode?
            context.env == "development"
          end
        end
      end

      it "applies timeout when method returns false" do
        result = task_class.call(sleep_duration: 2, env: "production")
        expect(result).to be_failed
        expect(result.metadata).to include(
          reason: "[CMDx::TimeoutError] execution exceeded 1 seconds"
        )
      end

      it "skips timeout when method returns true" do
        result = task_class.call(sleep_duration: 2, env: "development")
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end
    end

    context "with combined conditions (if and unless)" do
      let(:task_class) do
        Class.new(CMDx::Task) do
          use CMDx::Middlewares::Timeout,
              seconds: 1,
              if: proc { context.enable_timeout? },
              unless: proc { context.skip_timeout? }

          def call
            sleep_duration = context.sleep_duration || 0.1
            sleep(sleep_duration)
            context.value = "completed"
          end
        end
      end

      it "applies timeout when if is true and unless is false" do
        result = task_class.call(
          sleep_duration: 2,
          enable_timeout?: true,
          skip_timeout?: false
        )
        expect(result).to be_failed
        expect(result.metadata).to include(
          reason: "[CMDx::TimeoutError] execution exceeded 1 seconds"
        )
      end

      it "skips timeout when if is false" do
        result = task_class.call(
          sleep_duration: 2,
          enable_timeout?: false,
          skip_timeout?: false
        )
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end

      it "skips timeout when unless is true" do
        result = task_class.call(
          sleep_duration: 2,
          enable_timeout?: true,
          skip_timeout?: true
        )
        expect(result).to be_success
        expect(result.context.value).to eq("completed")
      end
    end
  end
end

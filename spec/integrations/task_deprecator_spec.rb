# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Deprecation Integration" do
  describe "deprecated tasks in task lifecycle" do
    context "with a fully deprecated task" do
      let(:deprecated_task_class) do
        create_simple_task(name: "DeprecatedProcessTask") do
          cmd_settings! deprecated: true

          def call
            context.processed = true
          end
        end
      end

      it "raises DeprecationError when task is instantiated" do
        expect { deprecated_task_class.new }.to raise_error(CMDx::DeprecationError, "DeprecatedProcessTask is deprecated")
      end

      it "raises DeprecationError when task is called via class method" do
        expect { deprecated_task_class.call }.to raise_error(CMDx::DeprecationError, "DeprecatedProcessTask is deprecated")
      end

      it "raises DeprecationError when task is called via class method with bang" do
        expect { deprecated_task_class.call! }.to raise_error(CMDx::DeprecationError, "DeprecatedProcessTask is deprecated")
      end
    end

    context "with a task marked for future deprecation" do
      let(:future_deprecated_task_class) do
        create_simple_task(name: "FutureDeprecatedTask") do
          cmd_settings! deprecated: false

          def call
            context.processed = true
          end
        end
      end

      it "logs warning when task is instantiated" do
        expected_message = "FutureDeprecatedTask will be deprecated. Find a replacement or stop usage"

        expect(CMDx::TaskDeprecator).to receive(:warn).with(expected_message, category: :deprecated)

        task = future_deprecated_task_class.new
        expect(task).to be_a(future_deprecated_task_class)
      end

      it "logs warning when task is called via class method" do
        expected_message = "FutureDeprecatedTask will be deprecated. Find a replacement or stop usage"

        expect(CMDx::TaskDeprecator).to receive(:warn).with(expected_message, category: :deprecated)

        result = future_deprecated_task_class.call
        expect(result).to be_success
        expect(result.context.processed).to be(true)
      end

      it "logs warning when task is called via class method with bang" do
        expected_message = "FutureDeprecatedTask will be deprecated. Find a replacement or stop usage"

        expect(CMDx::TaskDeprecator).to receive(:warn).with(expected_message, category: :deprecated)

        result = future_deprecated_task_class.call!
        expect(result).to be_success
        expect(result.context.processed).to be(true)
      end
    end

    context "with a regular task without deprecation" do
      let(:regular_task_class) do
        create_simple_task(name: "RegularTask") do
          def call
            context.processed = true
          end
        end
      end

      it "does not log any warnings or raise errors" do
        expect(CMDx::TaskDeprecator).not_to receive(:warn)
        expect { regular_task_class.new }.not_to raise_error

        result = regular_task_class.call
        expect(result).to be_success
        expect(result.context.processed).to be(true)
      end
    end

    context "with different truthy/falsy values" do
      shared_examples "truthy deprecated task" do |value|
        let(:task_class) do
          create_simple_task(name: "TruthyTask") do
            cmd_settings! deprecated: value
          end
        end

        it "raises DeprecationError for truthy value: #{value.inspect}" do
          expect { task_class.new }.to raise_error(CMDx::DeprecationError, "TruthyTask is deprecated")
        end
      end

      shared_examples "falsy deprecated task" do |value|
        let(:task_class) do
          create_simple_task(name: "FalsyTask") do
            cmd_settings! deprecated: value
          end
        end

        it "logs warning for falsy value: #{value.inspect}" do
          expected_message = "FalsyTask will be deprecated. Find a replacement or stop usage"
          expect(CMDx::TaskDeprecator).to receive(:warn).with(expected_message, category: :deprecated)

          expect { task_class.new }.not_to raise_error
        end
      end

      # Truthy values in Ruby (anything except nil and false)
      it_behaves_like "truthy deprecated task", true
      it_behaves_like "truthy deprecated task", "deprecated"
      it_behaves_like "truthy deprecated task", 1
      it_behaves_like "truthy deprecated task", 0 # 0 is truthy in Ruby!
      it_behaves_like "truthy deprecated task", "" # Empty string is truthy in Ruby!
      it_behaves_like "truthy deprecated task", :deprecated
      it_behaves_like "truthy deprecated task", []
      it_behaves_like "truthy deprecated task", {}

      # Falsy values in Ruby (only nil and false)
      it_behaves_like "falsy deprecated task", false
      it_behaves_like "falsy deprecated task", nil
    end
  end
end

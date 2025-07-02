# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ParameterValidator do
  describe ".call" do
    let(:task) { double("Task") }
    let(:task_class) { double("TaskClass") }
    let(:cmd_parameters) { double("Parameters") }
    let(:errors) { double("Errors") }

    before do
      allow(task_class).to receive(:cmd_parameters).and_return(cmd_parameters)
      allow(task).to receive_messages(class: task_class, errors: errors)
    end

    context "when parameter validation succeeds" do
      before do
        allow(cmd_parameters).to receive(:validate!).with(task)
        allow(errors).to receive(:empty?).and_return(true)
      end

      it "validates task parameters" do
        expect(cmd_parameters).to receive(:validate!).with(task)

        described_class.call(task)
      end

      it "does not fail the task when no errors are present" do
        expect(task).not_to receive(:fail!)

        described_class.call(task)
      end

      it "returns without setting failure state" do
        result = described_class.call(task)

        expect(result).to be_nil
      end
    end

    context "when parameter validation fails" do
      before do
        allow(cmd_parameters).to receive(:validate!).with(task)
        allow(errors).to receive(:empty?).and_return(false)
      end

      context "with single validation error" do
        let(:full_messages) { ["order_id is a required parameter"] }
        let(:messages_hash) { { order_id: ["is a required parameter"] } }

        before do
          allow(errors).to receive_messages(full_messages: full_messages, messages: messages_hash)
          allow(task).to receive(:fail!)
        end

        it "validates task parameters first" do
          expect(cmd_parameters).to receive(:validate!).with(task)

          described_class.call(task)
        end

        it "fails the task with proper reason" do
          expect(task).to receive(:fail!).with(
            reason: "order_id is a required parameter",
            messages: messages_hash
          )

          described_class.call(task)
        end

        it "uses full_messages for reason formatting" do
          expect(errors).to receive(:full_messages).and_return(full_messages)

          described_class.call(task)
        end

        it "passes raw messages to fail!" do
          expect(errors).to receive(:messages).and_return(messages_hash)

          described_class.call(task)
        end
      end

      context "with multiple validation errors" do
        let(:full_messages) do
          [
            "order_id is a required parameter",
            "email is invalid",
            "quantity must be greater than 0"
          ]
        end
        let(:messages_hash) do
          {
            order_id: ["is a required parameter"],
            email: ["is invalid"],
            quantity: ["must be greater than 0"]
          }
        end

        before do
          allow(errors).to receive_messages(full_messages: full_messages, messages: messages_hash)
          allow(task).to receive(:fail!)
        end

        it "validates task parameters first" do
          expect(cmd_parameters).to receive(:validate!).with(task)

          described_class.call(task)
        end

        it "joins multiple error messages with period and space" do
          expected_reason = "order_id is a required parameter. email is invalid. quantity must be greater than 0"

          expect(task).to receive(:fail!).with(
            reason: expected_reason,
            messages: messages_hash
          )

          described_class.call(task)
        end

        it "formats reason by joining full_messages" do
          expect(full_messages).to receive(:join).with(". ").and_call_original

          described_class.call(task)
        end

        it "includes all error messages in failure reason" do
          allow(task).to receive(:fail!) do |args|
            expect(args[:reason]).to include("order_id is a required parameter")
            expect(args[:reason]).to include("email is invalid")
            expect(args[:reason]).to include("quantity must be greater than 0")
          end

          described_class.call(task)
        end

        it "passes complete messages hash to fail!" do
          expect(task).to receive(:fail!).with(
            reason: anything,
            messages: messages_hash
          )

          described_class.call(task)
        end
      end

      context "with empty error messages" do
        let(:full_messages) { [] }
        let(:messages_hash) { {} }

        before do
          allow(errors).to receive_messages(full_messages: full_messages, messages: messages_hash)
          allow(task).to receive(:fail!)
        end

        it "fails task with empty reason string" do
          expect(task).to receive(:fail!).with(
            reason: "",
            messages: messages_hash
          )

          described_class.call(task)
        end
      end
    end

    context "when task has complex error structure" do
      let(:full_messages) { ["field_one cannot be blank", "field_two is too short"] }
      let(:messages_hash) do
        {
          field_one: ["cannot be blank"],
          field_two: ["is too short", "must be at least 3 characters"]
        }
      end

      before do
        allow(cmd_parameters).to receive(:validate!).with(task)
        allow(errors).to receive_messages(empty?: false, full_messages: full_messages, messages: messages_hash)
        allow(task).to receive(:fail!)
      end

      it "preserves complex message structure in messages parameter" do
        expect(task).to receive(:fail!) do |args|
          expect(args[:messages][:field_one]).to eq(["cannot be blank"])
          expect(args[:messages][:field_two]).to eq(["is too short", "must be at least 3 characters"])
        end

        described_class.call(task)
      end

      it "uses only full_messages for reason formatting" do
        expected_reason = "field_one cannot be blank. field_two is too short"

        expect(task).to receive(:fail!).with(
          reason: expected_reason,
          messages: messages_hash
        )

        described_class.call(task)
      end
    end

    context "when parameter validation raises an exception" do
      let(:validation_error) { StandardError.new("Validation system error") }

      before do
        allow(cmd_parameters).to receive(:validate!).with(task).and_raise(validation_error)
      end

      it "allows the exception to propagate" do
        expect { described_class.call(task) }.to raise_error(validation_error)
      end

      it "does not call task.fail! when validation raises" do
        expect(task).not_to receive(:fail!)

        expect { described_class.call(task) }.to raise_error(validation_error)
      end
    end
  end
end

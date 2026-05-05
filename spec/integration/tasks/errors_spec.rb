# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task error collection", type: :feature do
  describe "adding errors inside #work" do
    context "with no errors added" do
      subject(:result) { create_successful_task.execute }

      it "returns success with an empty errors object" do
        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(result.errors).to have_attributes(empty?: true, size: 0, count: 0)
        expect(result.errors.to_h).to eq({})
        expect(result.errors.to_s).to eq("")
      end
    end

    context "with a single error" do
      subject(:result) do
        create_task_class(name: "SingleError") do
          define_method(:work) { errors.add(:name, "is required") }
        end.execute
      end

      it "fails and surfaces the message in reason" do
        expect(result).to have_attributes(
          status: CMDx::Signal::FAILED,
          reason: "name is required",
          cause: nil
        )
        expect(result.errors.to_h).to eq(name: ["is required"])
        expect(result.errors.full_messages).to eq(name: ["name is required"])
      end
    end

    context "with multiple errors across attributes" do
      subject(:result) do
        create_task_class(name: "MultiError") do
          define_method(:work) do
            errors.add(:name, "is required")
            errors.add(:email, "is invalid")
            errors.add(:email, "is required")
          end
        end.execute
      end

      it "groups messages by attribute and computes size vs count distinctly" do
        expect(result.errors.size).to eq(2)
        expect(result.errors.count).to eq(3)
        expect(result.errors.keys).to contain_exactly(:name, :email)
        expect(result.errors.to_h).to eq(
          name: ["is required"],
          email: ["is invalid", "is required"]
        )
      end

      it "joins full messages for #to_s" do
        expect(result.errors.to_s)
          .to eq("name is required. email is invalid. email is required")
      end
    end

    context "with duplicate messages on the same attribute" do
      subject(:result) do
        create_task_class(name: "DupError") do
          define_method(:work) do
            errors.add(:name, "is required")
            errors.add(:name, "is required")
          end
        end.execute
      end

      it "deduplicates via Set" do
        expect(result.errors.to_h).to eq(name: ["is required"])
      end
    end

    context "with errors plus an explicit fail!" do
      subject(:result) do
        create_task_class(name: "ErrorsAndFail") do
          define_method(:work) do
            errors.add(:base, "something broke")
            fail!("explicit failure")
          end
        end.execute
      end

      it "prefers the explicit fail! reason while retaining the errors object" do
        expect(result).to have_attributes(reason: "explicit failure")
        expect(result.errors.to_h).to eq(base: ["something broke"])
      end
    end
  end

  describe "Errors query API" do
    subject(:errors) do
      create_task_class(name: "QueryErrors") do
        define_method(:work) do
          errors.add(:name, "is required")
          errors.add(:email, "is invalid")
        end
      end.execute.errors
    end

    it "answers key? for known and unknown keys" do
      expect(errors.key?(:name)).to be(true)
      expect(errors.key?(:other)).to be(false)
    end

    it "answers added? for known and unknown messages" do
      expect(errors.added?(:name, "is required")).to be(true)
      expect(errors.added?(:name, "different")).to be(false)
      expect(errors.added?(:other, "anything")).to be(false)
    end

    it "returns an empty frozen set for unknown keys" do
      expect(errors[:unknown]).to be_empty
    end
  end

  describe "#to_hash format switching" do
    subject(:errors) do
      create_task_class(name: "ToHashErrors") do
        define_method(:work) do
          errors.add(:name, "is required")
          errors.add(:email, "is invalid")
        end
      end.execute.errors
    end

    it "returns short messages by default" do
      expect(errors.to_hash).to eq(
        name: ["is required"],
        email: ["is invalid"]
      )
    end

    it "returns fully-qualified messages when passed true" do
      expect(errors.to_hash(true)).to eq(
        name: ["name is required"],
        email: ["email is invalid"]
      )
    end
  end

  describe "post-execution state" do
    it "freezes the errors object" do
      result = create_task_class(name: "FrozenErrors") do
        define_method(:work) { errors.add(:name, "is required") }
      end.execute

      expect(result.errors).to be_frozen
    end
  end

  describe "blocking execute!" do
    it "raises Fault with the collected error message" do
      task = create_task_class(name: "BangErrors") do
        define_method(:work) do
          errors.add(:name, "is required")
          errors.add(:email, "is invalid")
        end
      end

      expect { task.execute! }.to raise_error(CMDx::Fault, "name is required. email is invalid")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  describe ".call" do
    it "fails for nil values" do
      expect(described_class.call(nil, min: 1)).to be_a(CMDx::Validators::Failure)
    end

    it "raises without any option" do
      expect { described_class.call(1) }.to raise_error(ArgumentError, /unknown numeric validator options/)
    end

    context "with :within / :not_within" do
      it "passes within range" do
        expect(described_class.call(2, within: 1..3)).to be_nil
      end

      it "fails out of range" do
        expect(described_class.call(5, within: 1..3)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when inside a forbidden range" do
        expect(described_class.call(2, not_within: 1..3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :min / :max" do
      it "fails below min" do
        expect(described_class.call(0, min: 1, max: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "fails above max" do
        expect(described_class.call(9, min: 1, max: 3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :is / :is_not" do
      it "fails when not equal" do
        expect(described_class.call(2, is: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when equal to :is_not" do
        expect(described_class.call(2, is_not: 2)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :eq / :not_eq (aliases of :is / :is_not)" do
      it "passes when equal" do
        expect(described_class.call(2, eq: 2)).to be_nil
      end

      it "fails when not equal and reuses :is translation" do
        failure = described_class.call(2, eq: 3)
        expect(failure).to be_a(CMDx::Validators::Failure)
        expect(failure.message).to eq("must be 3")
      end

      it "passes when not equal to :not_eq" do
        expect(described_class.call(2, not_eq: 3)).to be_nil
      end

      it "fails when equal to :not_eq" do
        expect(described_class.call(2, not_eq: 2)).to be_a(CMDx::Validators::Failure)
      end

      it "honors :eq_message override" do
        failure = described_class.call(2, eq: 3, eq_message: "must equal %{is}")
        expect(failure.message).to eq("must equal 3")
      end
    end

    context "with :gte / :lte (aliases of :min / :max)" do
      it "passes when equal to :gte bound" do
        expect(described_class.call(1, gte: 1)).to be_nil
      end

      it "fails below :gte bound and reuses :min translation" do
        failure = described_class.call(0, gte: 1)
        expect(failure.message).to eq("must be at least 1")
      end

      it "passes when equal to :lte bound" do
        expect(described_class.call(3, lte: 3)).to be_nil
      end

      it "fails above :lte bound" do
        expect(described_class.call(4, lte: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "combines :gte and :lte as a range" do
        expect(described_class.call(2, gte: 1, lte: 3)).to be_nil
        expect(described_class.call(5, gte: 1, lte: 3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :gt" do
      it "passes when strictly above bound" do
        expect(described_class.call(2, gt: 1)).to be_nil
      end

      it "fails when equal to bound" do
        expect(described_class.call(1, gt: 1)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when below bound" do
        expect(described_class.call(0, gt: 1)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :lt" do
      it "passes when strictly below bound" do
        expect(described_class.call(2, lt: 3)).to be_nil
      end

      it "fails when equal to bound" do
        expect(described_class.call(3, lt: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when above bound" do
        expect(described_class.call(4, lt: 3)).to be_a(CMDx::Validators::Failure)
      end
    end
  end
end

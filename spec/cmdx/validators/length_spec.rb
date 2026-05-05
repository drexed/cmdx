# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  describe ".call" do
    it "fails for values without #length" do
      expect(described_class.call(nil, min: 1)).to be_a(CMDx::Validators::Failure)
    end

    it "raises without any length option" do
      expect { described_class.call("a") }.to raise_error(ArgumentError, /unknown length validator options/)
    end

    context "with :within" do
      it "passes when within range" do
        expect(described_class.call("ab", within: 1..3)).to be_nil
      end

      it "fails when out of range" do
        expect(described_class.call("abcd", within: 1..3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :not_within" do
      it "fails when within forbidden range" do
        expect(described_class.call("ab", not_within: 1..3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :min / :max" do
      it "passes inside the band" do
        expect(described_class.call("ab", min: 1, max: 3)).to be_nil
      end

      it "fails when too short" do
        expect(described_class.call("", min: 1, max: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when too long" do
        expect(described_class.call("abcd", min: 1, max: 3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :min only" do
      it "fails when below min" do
        expect(described_class.call("", min: 1)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :max only" do
      it "fails when above max" do
        expect(described_class.call("abcd", max: 3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :is / :is_not" do
      it "fails when not equal" do
        expect(described_class.call("abc", is: 2)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when equal to :is_not" do
        expect(described_class.call("ab", is_not: 2)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :eq / :not_eq (aliases of :is / :is_not)" do
      it "passes when length equals :eq" do
        expect(described_class.call("ab", eq: 2)).to be_nil
      end

      it "fails when length differs and reuses :is translation" do
        failure = described_class.call("abc", eq: 2)
        expect(failure.message).to eq("length must be 2")
      end

      it "fails when length equals :not_eq" do
        expect(described_class.call("ab", not_eq: 2)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :gte / :lte (aliases of :min / :max)" do
      it "passes when length meets :gte bound" do
        expect(described_class.call("ab", gte: 2)).to be_nil
      end

      it "fails below :gte bound and reuses :min translation" do
        failure = described_class.call("a", gte: 2)
        expect(failure.message).to eq("length must be at least 2")
      end

      it "fails above :lte bound" do
        expect(described_class.call("abcd", lte: 3)).to be_a(CMDx::Validators::Failure)
      end

      it "combines :gte and :lte as a range" do
        expect(described_class.call("ab", gte: 1, lte: 3)).to be_nil
        expect(described_class.call("abcd", gte: 1, lte: 3)).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with :gt / :lt (strict)" do
      it "fails when length equals :gt bound" do
        expect(described_class.call("ab", gt: 2)).to be_a(CMDx::Validators::Failure)
      end

      it "fails when length equals :lt bound" do
        expect(described_class.call("abc", lt: 3)).to be_a(CMDx::Validators::Failure)
      end
    end
  end
end

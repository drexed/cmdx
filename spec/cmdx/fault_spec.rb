# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Fault do
  let(:result) { SimulationTask.call(simulate: :skipped) }

  describe "#types" do
    it "inherits from correct classes" do
      expect(CMDx::Error).to inherit_from(StandardError)
      expect(described_class).to inherit_from(CMDx::Error)
      expect(CMDx::Skipped).to inherit_from(described_class)
      expect(CMDx::Failed).to inherit_from(described_class)
    end
  end

  describe "#build" do
    let(:fault) { described_class.build(result) }

    it "instantiates a matching CMDx based fault" do
      expect(fault.class).to eq(CMDx::Skipped)
    end
  end

  describe "#for?" do
    let(:fault) { described_class.build(result) }

    context "when match" do
      it "returns true" do
        begin
          matched = nil
          raise described_class.build(result)
        rescue CMDx::Skipped.for?(SimulationTask)
          matched = true
        rescue described_class
          matched = false
        end

        expect(matched).to be(true)
      end
    end

    context "when unmatched" do
      it "returns false" do
        begin
          matched = nil
          raise described_class.build(result)
        rescue CMDx::Failed.for?(SimulationTask)
          matched = true
        rescue described_class
          matched = false
        end

        expect(matched).to be(false)
      end
    end
  end

  describe "#matches?" do
    let(:fault) { described_class.build(result) }

    context "with block" do
      context "when match" do
        it "return true" do
          begin
            matched = nil
            raise described_class.build(result)
          rescue CMDx::Skipped.matches? { |e| e.task.is_a?(SimulationTask) }
            matched = true
          rescue described_class
            matched = false
          end

          expect(matched).to be(true)
        end
      end

      context "when unmatch" do
        it "return false" do
          begin
            matched = nil
            raise described_class.build(result)
          rescue CMDx::Failed.matches? { |e| e.task.is_a?(Integer) }
            matched = true
          rescue described_class
            matched = false
          end

          expect(matched).to be(false)
        end
      end
    end

    context "without block" do
      it "raises an ArgumentError" do
        expect do
          raise described_class.build(result)
        rescue described_class.matches?
          # Do work
        end.to raise_error(ArgumentError, "a block is required")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Fault do
  let(:result) { SimulationTask.call(simulate: :skipped) }
  let(:fault) { described_class.build(result) }

  describe "#types" do
    it "maintains proper inheritance hierarchy" do
      expect(CMDx::Error).to inherit_from(StandardError)
      expect(described_class).to inherit_from(CMDx::Error)
      expect(CMDx::Skipped).to inherit_from(described_class)
      expect(CMDx::Failed).to inherit_from(described_class)
    end
  end

  describe "#build" do
    it "instantiates correct fault type based on result" do
      expect(fault.class).to eq(CMDx::Skipped)
    end
  end

  describe "#for?" do
    context "when fault type matches" do
      it "catches the exception" do
        begin
          matched = nil
          raise fault
        rescue CMDx::Skipped.for?(SimulationTask)
          matched = true
        rescue described_class
          matched = false
        end

        expect(matched).to be(true)
      end
    end

    context "when fault type does not match" do
      it "does not catch the exception" do
        begin
          matched = nil
          raise fault
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
    context "when block is provided" do
      context "when condition matches" do
        it "catches the exception" do
          begin
            matched = nil
            raise fault
          rescue CMDx::Skipped.matches? { |e| e.task.is_a?(SimulationTask) }
            matched = true
          rescue described_class
            matched = false
          end

          expect(matched).to be(true)
        end
      end

      context "when condition does not match" do
        it "does not catch the exception" do
          begin
            matched = nil
            raise fault
          rescue CMDx::Failed.matches? { |e| e.task.is_a?(Integer) }
            matched = true
          rescue described_class
            matched = false
          end

          expect(matched).to be(false)
        end
      end
    end

    context "when block is not provided" do
      it "raises ArgumentError" do
        expect do
          raise fault
        rescue described_class.matches?
          # Do work
        end.to raise_error(ArgumentError, "block required")
      end
    end
  end
end

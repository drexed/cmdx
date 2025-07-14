# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::HashExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:hash) { { name: "John", "age" => 30, :count => 42 } }

  describe "#cmdx_fetch" do
    context "with symbol keys" do
      it "fetches value for existing symbol key" do
        expect(hash.cmdx_fetch(:name)).to eq("John")
      end

      it "fetches value for symbol key when string equivalent exists" do
        expect(hash.cmdx_fetch(:age)).to eq(30)
      end

      it "returns nil for non-existent symbol key" do
        expect(hash.cmdx_fetch(:missing)).to be_nil
      end
    end

    context "with string keys" do
      it "fetches value for existing string key" do
        expect(hash.cmdx_fetch("age")).to eq(30)
      end

      it "fetches value for string key when symbol equivalent exists" do
        expect(hash.cmdx_fetch("name")).to eq("John")
      end

      it "returns nil for non-existent string key" do
        expect(hash.cmdx_fetch("missing")).to be_nil
      end
    end

    context "with other key types" do
      let(:hash_with_numeric_keys) { { 1 => "one", 2 => "two" } }

      it "fetches value for integer key" do
        expect(hash_with_numeric_keys.cmdx_fetch(1)).to eq("one")
      end

      it "returns nil for non-existent integer key" do
        expect(hash_with_numeric_keys.cmdx_fetch(99)).to be_nil
      end
    end

    context "with edge cases" do
      let(:empty_hash) { {} }
      let(:hash_with_nil_value) { { key: nil } }
      let(:hash_with_false_value) { { key: false } }

      it "returns nil for empty hash" do
        expect(empty_hash.cmdx_fetch(:any_key)).to be_nil
      end

      it "returns nil when value is explicitly nil" do
        expect(hash_with_nil_value.cmdx_fetch(:key)).to be_nil
      end

      it "returns false when value is explicitly false" do
        expect(hash_with_false_value.cmdx_fetch(:key)).to be false
      end
    end
  end

  describe "#cmdx_key?" do
    context "with symbol keys" do
      it "returns true for existing symbol key" do
        expect(hash.cmdx_key?(:name)).to be true
      end

      it "returns true for symbol key when string equivalent exists" do
        expect(hash.cmdx_key?(:age)).to be true
      end

      it "returns false for non-existent symbol key" do
        expect(hash.cmdx_key?(:missing)).to be false
      end
    end

    context "with string keys" do
      it "returns true for existing string key" do
        expect(hash.cmdx_key?("age")).to be true
      end

      it "returns true for string key when symbol equivalent exists" do
        expect(hash.cmdx_key?("name")).to be true
      end

      it "returns false for non-existent string key" do
        expect(hash.cmdx_key?("missing")).to be false
      end
    end

    context "with other key types" do
      let(:hash_with_numeric_keys) { { 1 => "one", 2 => "two" } }

      it "returns true for existing integer key" do
        expect(hash_with_numeric_keys.cmdx_key?(1)).to be true
      end

      it "returns false for non-existent integer key" do
        expect(hash_with_numeric_keys.cmdx_key?(99)).to be false
      end
    end

    context "with edge cases" do
      let(:empty_hash) { {} }
      let(:hash_with_nil_value) { { key: nil } }
      let(:object_without_to_s) { Object.new }

      it "returns false for empty hash" do
        expect(empty_hash.cmdx_key?(:any_key)).to be false
      end

      it "returns true for key with nil value" do
        expect(hash_with_nil_value.cmdx_key?(:key)).to be true
      end

      it "handles objects that don't respond to to_s/to_sym gracefully" do
        allow(object_without_to_s).to receive(:to_s).and_raise(NoMethodError)
        allow(object_without_to_s).to receive(:to_sym).and_raise(NoMethodError)

        expect(hash.cmdx_key?(object_without_to_s)).to be false
      end
    end
  end

  describe "#cmdx_respond_to?" do
    context "with actual Hash methods" do
      it "returns true for existing Hash methods" do
        expect(hash.cmdx_respond_to?(:keys)).to be true
        expect(hash.cmdx_respond_to?(:values)).to be true
        expect(hash.cmdx_respond_to?(:each)).to be true
      end

      it "returns true for existing Hash methods as strings" do
        expect(hash.cmdx_respond_to?("keys")).to be true
        expect(hash.cmdx_respond_to?("values")).to be true
      end

      it "returns false for non-existent methods" do
        expect(hash.cmdx_respond_to?(:non_existent_method)).to be false
      end
    end

    context "with keys as method names" do
      it "returns true for existing symbol keys" do
        expect(hash.cmdx_respond_to?(:name)).to be true
        expect(hash.cmdx_respond_to?(:count)).to be true
      end

      it "returns true for existing string keys" do
        expect(hash.cmdx_respond_to?("age")).to be true
      end

      it "returns true for symbol key when string equivalent exists" do
        expect(hash.cmdx_respond_to?(:age)).to be true
      end

      it "returns true for string key when symbol equivalent exists" do
        expect(hash.cmdx_respond_to?("name")).to be true
      end

      it "returns false for non-existent keys" do
        expect(hash.cmdx_respond_to?(:missing)).to be false
        expect(hash.cmdx_respond_to?("missing")).to be false
      end
    end

    context "with include_private parameter" do
      it "respects include_private parameter for methods" do
        expect(hash.cmdx_respond_to?(:initialize, true)).to be true
        expect(hash.cmdx_respond_to?(:initialize, false)).to be false
      end

      it "works with keys regardless of include_private parameter" do
        expect(hash.cmdx_respond_to?(:name, true)).to be true
        expect(hash.cmdx_respond_to?(:name, false)).to be true
      end
    end

    context "with edge cases" do
      let(:empty_hash) { {} }
      let(:object_without_to_sym) { Object.new }

      it "returns false for empty hash with non-existent key" do
        expect(empty_hash.cmdx_respond_to?(:any_key)).to be false
      end

      it "handles objects that don't respond to to_sym gracefully" do
        allow(object_without_to_sym).to receive(:to_sym).and_raise(NoMethodError)

        expect(hash.cmdx_respond_to?(object_without_to_sym)).to be false
      end
    end
  end

  describe "integration" do
    context "with mixed symbol and string keys" do
      let(:mixed_hash) { { :symbol_key => "symbol_value", "string_key" => "string_value" } }

      it "works consistently across all methods" do
        # cmdx_fetch
        expect(mixed_hash.cmdx_fetch(:symbol_key)).to eq("symbol_value")
        expect(mixed_hash.cmdx_fetch("symbol_key")).to eq("symbol_value")
        expect(mixed_hash.cmdx_fetch(:string_key)).to eq("string_value")
        expect(mixed_hash.cmdx_fetch("string_key")).to eq("string_value")

        # cmdx_key?
        expect(mixed_hash.cmdx_key?(:symbol_key)).to be true
        expect(mixed_hash.cmdx_key?("symbol_key")).to be true
        expect(mixed_hash.cmdx_key?(:string_key)).to be true
        expect(mixed_hash.cmdx_key?("string_key")).to be true

        # cmdx_respond_to?
        expect(mixed_hash.cmdx_respond_to?(:symbol_key)).to be true
        expect(mixed_hash.cmdx_respond_to?("symbol_key")).to be true
        expect(mixed_hash.cmdx_respond_to?(:string_key)).to be true
        expect(mixed_hash.cmdx_respond_to?("string_key")).to be true
      end
    end
  end
end

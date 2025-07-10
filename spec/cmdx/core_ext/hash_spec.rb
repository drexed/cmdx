# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::HashExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  let(:test_hash) { { name: "John", "age" => 30, id: 123 } }
  let(:empty_hash) { {} }
  let(:symbol_hash) { { first_name: "Jane", last_name: "Doe" } }
  let(:string_hash) { { "email" => "jane@example.com", "phone" => "555-1234" } }

  describe "#cmdx_fetch" do
    context "with symbol keys" do
      it "returns value for existing symbol key" do
        result = test_hash.cmdx_fetch(:name)

        expect(result).to eq("John")
      end

      it "returns value for symbol key when string equivalent exists" do
        result = test_hash.cmdx_fetch(:age)

        expect(result).to eq(30)
      end

      it "returns nil for non-existent symbol key" do
        result = test_hash.cmdx_fetch(:missing)

        expect(result).to be_nil
      end

      it "tries symbol key first then string conversion" do
        allow(test_hash).to receive(:fetch).with(:name).and_yield
        allow(test_hash).to receive(:[]).with("name").and_return("fallback")

        result = test_hash.cmdx_fetch(:name)

        expect(result).to eq("fallback")
      end
    end

    context "with string keys" do
      it "returns value for existing string key" do
        result = test_hash.cmdx_fetch("age")

        expect(result).to eq(30)
      end

      it "returns value for string key when symbol equivalent exists" do
        result = test_hash.cmdx_fetch("name")

        expect(result).to eq("John")
      end

      it "returns nil for non-existent string key" do
        result = test_hash.cmdx_fetch("missing")

        expect(result).to be_nil
      end

      it "tries string key first then symbol conversion" do
        allow(test_hash).to receive(:fetch).with("age").and_yield
        allow(test_hash).to receive(:[]).with(:age).and_return("fallback")

        result = test_hash.cmdx_fetch("age")

        expect(result).to eq("fallback")
      end
    end

    context "with other key types" do
      it "returns value for numeric keys" do
        hash_with_numeric = { 1 => "one", 2 => "two" }

        result = hash_with_numeric.cmdx_fetch(1)

        expect(result).to eq("one")
      end

      it "returns nil for non-existent numeric keys" do
        result = test_hash.cmdx_fetch(999)

        expect(result).to be_nil
      end

      it "uses direct hash access for non-string, non-symbol keys" do
        hash_with_object = { Object.new => "object_value" }
        key = hash_with_object.keys.first

        result = hash_with_object.cmdx_fetch(key)

        expect(result).to eq("object_value")
      end
    end

    context "with empty hash" do
      it "returns nil for any key" do
        result = empty_hash.cmdx_fetch(:any_key)

        expect(result).to be_nil
      end
    end

    context "with symbol-only hash" do
      it "finds symbol keys directly" do
        result = symbol_hash.cmdx_fetch(:first_name)

        expect(result).to eq("Jane")
      end

      it "finds symbol keys via string conversion" do
        result = symbol_hash.cmdx_fetch("first_name")

        expect(result).to eq("Jane")
      end
    end

    context "with string-only hash" do
      it "finds string keys directly" do
        result = string_hash.cmdx_fetch("email")

        expect(result).to eq("jane@example.com")
      end

      it "finds string keys via symbol conversion" do
        result = string_hash.cmdx_fetch(:email)

        expect(result).to eq("jane@example.com")
      end
    end
  end

  describe "#cmdx_key?" do
    context "with existing keys" do
      it "returns true for existing symbol key" do
        result = test_hash.cmdx_key?(:name)

        expect(result).to be true
      end

      it "returns true for existing string key" do
        result = test_hash.cmdx_key?("age")

        expect(result).to be true
      end

      it "returns true for symbol key when string equivalent exists" do
        result = test_hash.cmdx_key?(:age)

        expect(result).to be true
      end

      it "returns true for string key when symbol equivalent exists" do
        result = test_hash.cmdx_key?("name")

        expect(result).to be true
      end
    end

    context "with non-existent keys" do
      it "returns false for non-existent symbol key" do
        result = test_hash.cmdx_key?(:missing)

        expect(result).to be false
      end

      it "returns false for non-existent string key" do
        result = test_hash.cmdx_key?("missing")

        expect(result).to be false
      end
    end

    context "with other key types" do
      it "returns true for existing numeric key" do
        hash_with_numeric = { 1 => "one" }

        result = hash_with_numeric.cmdx_key?(1)

        expect(result).to be true
      end

      it "returns false for non-existent numeric key" do
        result = test_hash.cmdx_key?(999)

        expect(result).to be false
      end

      it "handles object keys" do
        key = Object.new
        hash_with_object = { key => "value" }

        result = hash_with_object.cmdx_key?(key)

        expect(result).to be true
      end
    end

    context "with key conversion errors" do
      it "returns false when key conversion raises NoMethodError" do
        problematic_key = Object.new
        allow(problematic_key).to receive(:to_s).and_raise(NoMethodError)
        allow(problematic_key).to receive(:to_sym).and_raise(NoMethodError)

        result = test_hash.cmdx_key?(problematic_key)

        expect(result).to be false
      end
    end

    context "with key? method checking" do
      it "calls key? with original key first" do
        allow(test_hash).to receive(:key?).with(:name).and_return(true)

        test_hash.cmdx_key?(:name)

        expect(test_hash).to have_received(:key?).with(:name)
      end

      it "calls key? with converted key when original fails" do
        allow(test_hash).to receive(:key?).with(:missing).and_return(false)
        allow(test_hash).to receive(:key?).with("missing").and_return(false)

        test_hash.cmdx_key?(:missing)

        expect(test_hash).to have_received(:key?).with(:missing)
        expect(test_hash).to have_received(:key?).with("missing")
      end
    end
  end

  describe "#cmdx_respond_to?" do
    context "with real hash methods" do
      it "returns true for existing Hash methods" do
        result = test_hash.cmdx_respond_to?(:keys)

        expect(result).to be true
      end

      it "returns true for private Hash methods when include_private is true" do
        result = test_hash.cmdx_respond_to?(:initialize, true)

        expect(result).to be true
      end

      it "returns false for private Hash methods when include_private is false" do
        result = test_hash.cmdx_respond_to?(:initialize, false)

        expect(result).to be false
      end
    end

    context "with hash keys as methods" do
      it "returns true when hash contains symbol key" do
        result = test_hash.cmdx_respond_to?(:name)

        expect(result).to be true
      end

      it "returns true when hash contains string key" do
        result = test_hash.cmdx_respond_to?("age")

        expect(result).to be true
      end

      it "returns true for symbol method when string key exists" do
        result = test_hash.cmdx_respond_to?(:age)

        expect(result).to be true
      end

      it "returns true for string method when symbol key exists" do
        result = test_hash.cmdx_respond_to?("name")

        expect(result).to be true
      end
    end

    context "with non-existent methods and keys" do
      it "returns false when method does not exist and key not found" do
        result = test_hash.cmdx_respond_to?(:nonexistent_method)

        expect(result).to be false
      end
    end

    context "with respond_to? method checking" do
      it "calls original respond_to? method first" do
        allow(test_hash).to receive(:respond_to?).with(:keys, false).and_return(true)

        test_hash.cmdx_respond_to?(:keys)

        expect(test_hash).to have_received(:respond_to?).with(:keys, false)
      end

      it "falls back to cmdx_key? when respond_to? returns false" do
        allow(test_hash).to receive(:respond_to?).with(:name, false).and_return(false)
        allow(test_hash).to receive(:cmdx_key?).with(:name).and_return(true)

        result = test_hash.cmdx_respond_to?(:name)

        expect(result).to be true
        expect(test_hash).to have_received(:cmdx_key?).with(:name)
      end

      it "handles NoMethodError from respond_to? by falling back to cmdx_key?" do
        allow(test_hash).to receive(:respond_to?).and_raise(NoMethodError)
        allow(test_hash).to receive(:cmdx_key?).with(:name).and_return(true)

        result = test_hash.cmdx_respond_to?(:name)

        expect(result).to be true
        expect(test_hash).to have_received(:cmdx_key?).with(:name)
      end
    end

    context "with include_private parameter" do
      it "forwards include_private parameter to respond_to?" do
        allow(test_hash).to receive(:respond_to?).with(:keys, true).and_return(true)

        test_hash.cmdx_respond_to?(:keys, true)

        expect(test_hash).to have_received(:respond_to?).with(:keys, true)
      end

      it "defaults include_private to false" do
        allow(test_hash).to receive(:respond_to?).with(:keys, false).and_return(true)

        test_hash.cmdx_respond_to?(:keys)

        expect(test_hash).to have_received(:respond_to?).with(:keys, false)
      end
    end

    context "with key conversion" do
      it "converts symbol to symbol when checking respond_to?" do
        allow(test_hash).to receive(:respond_to?).with(:name, false).and_return(false)
        allow(test_hash).to receive(:cmdx_key?).with(:name).and_return(true)

        test_hash.cmdx_respond_to?(:name)

        expect(test_hash).to have_received(:respond_to?).with(:name, false)
      end

      it "converts string to symbol when checking respond_to?" do
        allow(test_hash).to receive(:respond_to?).with(:age, false).and_return(false)
        allow(test_hash).to receive(:cmdx_key?).with("age").and_return(true)

        test_hash.cmdx_respond_to?("age")

        expect(test_hash).to have_received(:respond_to?).with(:age, false)
      end
    end
  end

  describe "Hash inclusion" do
    it "extends Hash class with HashExtensions" do
      expect(Hash.ancestors).to include(described_class)
    end

    it "makes cmdx_fetch available on all hashes" do
      new_hash = {}

      expect(new_hash).to respond_to(:cmdx_fetch)
    end

    it "makes cmdx_key? available on all hashes" do
      new_hash = {}

      expect(new_hash).to respond_to(:cmdx_key?)
    end

    it "makes cmdx_respond_to? available on all hashes" do
      new_hash = {}

      expect(new_hash).to respond_to(:cmdx_respond_to?)
    end
  end
end

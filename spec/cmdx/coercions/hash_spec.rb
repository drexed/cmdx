# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash do
  describe ".call" do
    it "returns a Hash unchanged" do
      h = { a: 1 }
      expect(described_class.call(h)).to equal(h)
    end

    it "converts an Array of pairs" do
      expect(described_class.call([[:a, 1], [:b, 2]])).to eq({ a: 1, b: 2 })
    end

    it "uses #to_h when available" do
      wrapper = Class.new do
        def initialize(data)
          @data = data
        end

        def to_h
          @data
        end
      end
      expect(described_class.call(wrapper.new({ "k" => :v }))).to eq({ "k" => :v })
    end

    it "raises CMDx::Error when no hash conversion exists" do
      expect { described_class.call(123) }.to raise_error(CMDx::Error, /hash/)
    end
  end
end

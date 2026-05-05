# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe "#initialize" do
    it "starts empty" do
      expect(errors).to be_empty
      expect(errors.messages).to eq({})
    end
  end

  describe "#add" do
    it "appends a message under the key" do
      errors.add(:name, "is required")
      expect(errors[:name]).to include("is required")
    end

    it "deduplicates identical messages" do
      errors.add(:name, "is required")
      errors.add(:name, "is required")
      expect(errors[:name].size).to eq(1)
    end

    it "accumulates distinct messages under the same key" do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
      expect(errors[:name]).to contain_exactly("is required", "is too short")
    end

    it "is aliased as []=" do
      errors[:name] = "is required"
      expect(errors[:name]).to include("is required")
    end
  end

  describe "#merge!" do
    let(:other) { described_class.new }

    it "copies messages from another Errors instance" do
      other.add(:name, "is required")
      other.add(:age, "too young")
      errors.merge!(other)

      expect(errors.to_h).to eq(name: ["is required"], age: ["too young"])
    end

    it "preserves existing messages and unions with incoming ones" do
      errors.add(:name, "is required")
      other.add(:name, "is too short")
      other.add(:age, "too young")
      errors.merge!(other)

      expect(errors[:name]).to contain_exactly("is required", "is too short")
      expect(errors[:age]).to contain_exactly("too young")
    end

    it "deduplicates overlapping messages under the same key" do
      errors.add(:name, "is required")
      other.add(:name, "is required")
      errors.merge!(other)

      expect(errors[:name]).to contain_exactly("is required")
    end

    it "is a no-op when the other container is empty" do
      errors.add(:name, "is required")
      errors.merge!(other)

      expect(errors.to_h).to eq(name: ["is required"])
    end

    it "accepts any object responding to #to_hash" do
      hash_like = Class.new { def to_hash = { name: ["is required"] } }.new
      errors.merge!(hash_like)

      expect(errors[:name]).to contain_exactly("is required")
    end
  end

  describe "#[]" do
    it "returns the array of messages for a key" do
      errors.add(:age, "too young")
      expect(errors[:age]).to be_a(Array)
      expect(errors[:age]).to include("too young")
    end

    it "returns an empty set when the key is absent" do
      expect(errors[:missing]).to be_empty
    end
  end

  describe "#added?" do
    it "is true when the exact message was added" do
      errors.add(:name, "is required")
      expect(errors.added?(:name, "is required")).to be(true)
    end

    it "is false for a different message" do
      errors.add(:name, "is required")
      expect(errors.added?(:name, "is too short")).to be(false)
    end

    it "is false when the key is absent" do
      expect(errors.added?(:missing, "x")).to be(false)
    end
  end

  describe "#key?" do
    it "is true only for keys that have at least one message" do
      errors.add(:name, "bad")
      expect(errors.key?(:name)).to be(true)
      expect(errors.key?(:age)).to be(false)
    end
  end

  describe "#keys" do
    it "lists keys in insertion order" do
      errors.add(:a, "x")
      errors.add(:b, "y")
      expect(errors.keys).to eq(%i[a b])
    end
  end

  describe "#size and #count" do
    before do
      errors.add(:a, "x")
      errors.add(:a, "y")
      errors.add(:b, "z")
    end

    it "size returns the number of keys" do
      expect(errors.size).to eq(2)
    end

    it "count returns the total number of messages" do
      expect(errors.count).to eq(3)
    end
  end

  describe "iteration" do
    before do
      errors.add(:a, "x")
      errors.add(:b, "y")
    end

    it "each yields [key, set] pairs" do
      pairs = []
      errors.each { |k, v| pairs << [k, v.to_a] } # rubocop:disable Style/MapIntoArray
      expect(pairs).to eq([[:a, ["x"]], [:b, ["y"]]])
    end

    it "each_key yields each key" do
      expect(errors.each_key.to_a).to eq(%i[a b])
    end

    it "each_value yields each set" do
      expect(errors.each_value.map(&:to_a)).to eq([["x"], ["y"]])
    end
  end

  describe "#delete" do
    it "removes all messages for the key" do
      errors.add(:a, "x")
      errors.delete(:a)
      expect(errors).to be_empty
    end
  end

  describe "#clear" do
    it "removes all messages" do
      errors.add(:a, "x")
      errors.add(:b, "y")
      errors.clear
      expect(errors).to be_empty
    end
  end

  describe "#full_messages" do
    it "prefixes each message with its key" do
      errors.add(:name, "is required")
      errors.add(:age, "too young")

      expect(errors.full_messages).to eq(
        name: ["name is required"],
        age: ["age too young"]
      )
    end
  end

  describe "#to_h" do
    it "converts sets to arrays" do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")

      expect(errors.to_h[:name]).to contain_exactly("is required", "is too short")
    end
  end

  describe "#to_hash" do
    before do
      errors.add(:name, "is required")
    end

    it "returns the plain hash when full is false" do
      expect(errors.to_hash).to eq(name: ["is required"])
    end

    it "returns full messages when full is true" do
      expect(errors.to_hash(true)).to eq(name: ["name is required"])
    end
  end

  describe "#to_s" do
    it "joins full messages with '. '" do
      errors.add(:name, "is required")
      errors.add(:age, "too young")

      expect(errors.to_s).to eq("name is required. age too young")
    end

    it "returns an empty string when no messages are present" do
      expect(errors.to_s).to eq("")
    end
  end

  describe "pattern matching support" do
    before do
      errors.add(:name, "is required")
      errors.add(:age, "too young")
    end

    describe "#deconstruct_keys" do
      it "returns the full to_h when keys is nil" do
        expect(errors.deconstruct_keys(nil)).to eq(name: ["is required"], age: ["too young"])
      end

      it "slices to the requested keys" do
        expect(errors.deconstruct_keys([:name])).to eq(name: ["is required"])
        expect(errors.deconstruct_keys([:missing])).to eq({})
      end

      it "supports hash patterns in case/in" do
        matched =
          case errors
          in { name: [String => msg, *] }
            msg
          end

        expect(matched).to eq("is required")
      end
    end

    describe "#deconstruct" do
      it "returns the messages as an array of [key, messages] pairs" do
        expect(errors.deconstruct).to contain_exactly(
          [:name, ["is required"]],
          [:age, ["too young"]]
        )
      end
    end
  end

  describe "#as_json" do
    it "returns to_h" do
      errors.add(:name, "is required")
      expect(errors.as_json).to eq(errors.to_h)
    end
  end

  describe "#to_json" do
    it "emits a JSON string with symbol keys stringified and messages as arrays" do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
      errors.add(:age, "too young")

      parsed = JSON.parse(errors.to_json)

      expect(parsed.keys).to contain_exactly("name", "age")
      expect(parsed["name"]).to contain_exactly("is required", "is too short")
      expect(parsed["age"]).to eq(["too young"])
    end

    it "emits an empty object when there are no messages" do
      expect(errors.to_json).to eq("{}")
    end
  end

  describe "#freeze" do
    it "freezes the messages hash and each message set" do
      errors.add(:name, "is required")
      errors.freeze

      expect(errors).to be_frozen
      expect(errors.messages).to be_frozen
      expect(errors.messages[:name]).to be_frozen
    end
  end
end

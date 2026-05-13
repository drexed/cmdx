# frozen_string_literal: true

RSpec.describe CMDx::Validators do
  subject(:validators) { described_class.new }

  let(:task) { create_task_class.new }

  describe "#initialize" do
    it "registers the built-in validators" do
      expect(validators.registry.keys).to contain_exactly(
        :absence, :exclusion, :format, :inclusion, :length, :numeric, :presence
      )
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = validators.dup
      copy.deregister(:presence)
      expect(validators.registry).to have_key(:presence)
      expect(copy.registry).not_to have_key(:presence)
    end
  end

  describe "#register" do
    it "stores a callable" do
      c = ->(v, **) { v }
      validators.register(:custom, c)
      expect(validators.lookup(:custom)).to be(c)
    end

    it "stores a block" do
      validators.register(:x) { |v, **| v }
      expect(validators.lookup(:x)).to be_a(Proc)
    end

    it "raises when both a callable and block are given" do
      expect { validators.register(:x, ->(v, **) { v }) { |v, **| v } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { validators.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      validators.deregister(:presence)
      expect(validators.registry).not_to have_key(:presence)
    end
  end

  describe "#key?" do
    it "reports membership" do
      expect(validators.key?(:presence)).to be(true)
      expect(validators.key?(:bogus)).to be(false)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { validators.lookup(:bogus) }.to raise_error(CMDx::UnknownEntryError, /unknown validator :bogus/)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(validators.size).to eq(7)
      expect(validators).not_to be_empty
    end
  end

  describe "#extract" do
    it "returns EMPTY_HASH for empty options" do
      expect(validators.extract({})).to eq({})
    end

    it "picks up registry keys from options" do
      expect(validators.extract(presence: true, other: 1)).to eq(presence: true)
    end

    it "includes :validate entries" do
      expect(validators.extract(validate: ->(_, _) {})).to have_key(:validate)
    end
  end

  describe "#validate" do
    it "adds errors for failing built-in validators" do
      validators.validate(task, :name, nil, presence: true)
      expect(task.errors[:name]).not_to be_empty
    end

    it "honors :allow_nil" do
      validators.validate(task, :name, nil, presence: { allow_nil: true })
      expect(task.errors).to be_empty
    end

    it "honors :if guards" do
      validators.validate(task, :name, nil, presence: { if: proc { false } })
      expect(task.errors).to be_empty
    end

    it "accepts array shorthand for :in" do
      validators.validate(task, :x, :c, inclusion: %i[a b])
      expect(task.errors[:x]).not_to be_empty
    end

    it "accepts regexp shorthand for :with" do
      validators.validate(task, :x, "Ada", format: /\A\d+\z/)
      expect(task.errors[:x]).not_to be_empty
    end

    it "skips when raw_options is false or nil" do
      validators.validate(task, :x, nil, presence: false)
      expect(task.errors).to be_empty
    end

    it "raises for unsupported raw_options" do
      expect do
        validators.validate(task, :x, nil, presence: 42)
      end.to raise_error(ArgumentError, /unsupported validator option format/)
    end

    it "invokes :validate custom handlers and records their failure messages" do
      handler = ->(_v) { CMDx::Validators::Failure.new("broken") }
      validators.validate(task, :x, 1, validate: handler)
      expect(task.errors[:x]).to include("broken")
    end

    it "ignores :validate handlers that do not return a Failure" do
      handler = ->(_v) {}
      validators.validate(task, :x, 1, validate: handler)
      expect(task.errors).to be_empty
    end
  end
end

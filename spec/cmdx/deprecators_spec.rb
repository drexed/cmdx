# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Deprecators do
  subject(:deprecators) { described_class.new }

  describe "#initialize" do
    it "registers the built-in deprecation actions" do
      expect(deprecators.registry.keys).to contain_exactly(:log, :warn, :error)
      expect(deprecators.lookup(:log)).to be(CMDx::Deprecators::Log)
      expect(deprecators.lookup(:warn)).to be(CMDx::Deprecators::Warn)
      expect(deprecators.lookup(:error)).to be(CMDx::Deprecators::Error)
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = deprecators.dup
      copy.deregister(:error)
      expect(deprecators.registry).to have_key(:error)
      expect(copy.registry).not_to have_key(:error)
    end
  end

  describe "#register" do
    it "stores a callable" do
      c = ->(_t) {}
      deprecators.register(:custom, c)
      expect(deprecators.lookup(:custom)).to be(c)
    end

    it "stores a block" do
      deprecators.register(:b) { |_t| nil }
      expect(deprecators.lookup(:b)).to be_a(Proc)
    end

    it "raises when both a callable and block are given" do
      c = ->(_) {}
      expect { deprecators.register(:x, c) { |_| nil } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { deprecators.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      deprecators.deregister(:log)
      expect(deprecators.registry).not_to have_key(:log)
    end
  end

  describe "#key?" do
    it "reports membership" do
      expect(deprecators.key?(:log)).to be(true)
      expect(deprecators.key?(:bogus)).to be(false)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { deprecators.lookup(:bogus) }
        .to raise_error(ArgumentError, "unknown deprecator: :bogus")
    end
  end

  describe "#resolve" do
    it "returns nil when spec is nil" do
      expect(deprecators.resolve(nil)).to be_nil
    end

    it "looks up registered symbols" do
      expect(deprecators.resolve(:log)).to be(deprecators.lookup(:log))
    end

    it "passes through arbitrary callables" do
      c = ->(_t) {}
      expect(deprecators.resolve(c)).to be(c)
    end

    it "raises on unknown symbols" do
      expect { deprecators.resolve(:bogus) }
        .to raise_error(ArgumentError, "unknown deprecator: :bogus")
    end

    it "raises on non-callable specs" do
      expect { deprecators.resolve(Object.new) }
        .to raise_error(ArgumentError, /unknown deprecator/)
    end
  end

  describe "built-in behavior" do
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output) }
    let(:task) do
      log = logger
      Class.new do
        define_method(:logger) { log }
      end.new
    end

    it ":log writes a deprecation warning via the task logger" do
      deprecators.lookup(:log).call(task)
      expect(log_output.string).to include("DEPRECATED:", task.class.to_s)
    end

    it ":warn writes to stderr via Kernel.warn" do
      expect { deprecators.lookup(:warn).call(task) }
        .to output(/DEPRECATED: migrate/).to_stderr
    end

    it ":error raises DeprecationError" do
      expect { deprecators.lookup(:error).call(task) }
        .to raise_error(CMDx::DeprecationError, /usage prohibited/)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(deprecators.size).to eq(3)
      expect(deprecators).not_to be_empty
    end
  end
end

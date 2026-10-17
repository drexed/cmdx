# frozen_string_literal: true

RSpec.describe CMDx::CircuitBreaker do
  let(:task_class) do
    create_task_class(name: "BreakerTask") do
      required :sku, coerce: :string

      define_method(:work) do
        context.runs = (context.runs || 0) + 1
      end
    end
  end

  describe ".disabled" do
    it "returns a configuration with no key" do
      expect(described_class.disabled).not_to be_enabled
    end
  end

  describe "#build" do
    it "merges options and replaces the key" do
      base = described_class.new(:class, threshold: 3)
      built = base.build(:sku, threshold: 5, cool_off: 10)

      expect(built.key).to eq(:sku)
      expect(built.threshold).to eq(5)
      expect(built.cool_off).to eq(10)
    end

    it "enables with :class when only options are passed on a disabled config" do
      built = described_class.disabled.build(nil, threshold: 2)

      expect(built).to be_enabled
      expect(built.key).to eq(:class)
      expect(built.threshold).to eq(2)
    end

    it "returns self when nothing changes" do
      config = described_class.new(:class)
      expect(config.build(nil, {})).to be(config)
    end
  end

  describe "#process" do
    it "runs work when disabled" do
      task = task_class.new(sku: "A")
      config = described_class.disabled

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "opens after threshold failures and fails fast" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "TripTask") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result).to be_ko
      expect(result.metadata[:code]).to eq(:circuit_open)
    end

    it "clears the failure counter after success" do
      err = Class.new(StandardError)
      attempts = 0
      klass = create_task_class(name: "RecoverTask") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string

        define_method(:work) do
          attempts += 1
          raise err if attempts == 1

          context.ok = true
        end
      end

      expect(klass.execute(sku: "A")).to be_ko
      expect(klass.execute(sku: "A")).to be_ok
      expect(klass.execute(sku: "A")).to be_ok
    end

    it "skips when on_open is :skip" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "SkipOpenTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on_open: :skip
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result).to be_skipped
      expect(result.metadata[:code]).to eq(:circuit_open)
    end
  end
end

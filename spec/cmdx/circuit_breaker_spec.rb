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

    it "includes the open store key and retry_after when the circuit is open" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "MetadataOpenTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on_open: :skip
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result.metadata[:circuit_breaker_key]).to eq("cmdx:cb:#{klass.name}:open")
      expect(result.metadata[:retry_after]).to be_between(1, 60)
    end

    it "does not trip when the keyed segment is blank" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "KeyedBlankTask") do
        circuit_breaker :tenant_id, threshold: 1, cool_off: 60
        optional :tenant_id

        define_method(:work) { raise err }
      end

      result = klass.execute

      expect(result).to be_ko
      expect(result.metadata[:code]).not_to eq(:circuit_open)
    end

    it "does not count exceptions outside on:" do
      api_err = Class.new(StandardError)
      klass = create_task_class(name: "FilteredTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on: [api_err]
        required :sku, coerce: :string

        define_method(:work) { raise NoMethodError }
      end

      3.times { klass.execute(sku: "A") }

      expect(klass.execute(sku: "A").metadata[:code]).not_to eq(:circuit_open)
    end

    it "re-raises the work exception when the store fails during trip_open" do
      err = Class.new(StandardError) { def message = "dependency down" }
      failing_store = Class.new(CMDx::Stores::Memory) do
        def incr(*)
          raise StandardError, "store down"
        end
      end.new

      allow(CMDx.configuration).to receive(:store).and_return(failing_store)

      klass = create_task_class(name: "StoreTripFailTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      result = klass.execute(sku: "A")

      expect(result).to be_ko
      expect(result.reason).to include("dependency down")
      expect(result.metadata[:code]).not_to eq(:circuit_open)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Task circuit_breaker", type: :feature do
  it "inherits configuration from the superclass" do
    parent = create_task_class(name: "ParentBreaker") do
      circuit_breaker :class, threshold: 9
    end
    child = create_task_class(base: parent, name: "ChildBreaker") do
      required :sku, coerce: :string

      define_method(:work) { nil }
    end

    expect(child.circuit_breaker.threshold).to eq(9)
  end

  it "can be disabled on a subclass" do
    parent = create_task_class(name: "ParentEnabled") do
      circuit_breaker :class, threshold: 1
    end
    child = create_task_class(base: parent, name: "ChildDisabled") do
      circuit_breaker false
      required :sku, coerce: :string

      define_method(:work) { raise StandardError, "boom" }
    end

    expect(child.circuit_breaker).not_to be_enabled
    expect(child.execute(sku: "A").metadata[:code]).not_to eq(:circuit_open)
  end

  it "honors if and unless gates before opening the circuit" do
    err = Class.new(StandardError)
    attempts = 0
    klass = create_task_class(name: "GatedBreaker") do
      circuit_breaker :class, threshold: 1, cool_off: 60, if: :breaker_on?, unless: :maintenance?
      required :sku, coerce: :string
      optional :breaker_on, default: true
      optional :maintenance, default: false

      define_method(:work) do
        attempts += 1
        raise err
      end
      define_method(:breaker_on?) { breaker_on }
      define_method(:maintenance?) { maintenance }
    end

    klass.execute(sku: "A", breaker_on: false)
    klass.execute(sku: "A", breaker_on: true, maintenance: true)
    klass.execute(sku: "A", breaker_on: true, maintenance: false)
    result = klass.execute(sku: "A", breaker_on: true, maintenance: false)

    expect(attempts).to eq(3)
    expect(result.metadata[:code]).to eq(:circuit_open)
  end

  it "lets subclasses override the breaker key resolver" do
    err = Class.new(StandardError)
    parent = create_task_class(name: "ParentSkuBreaker") do
      circuit_breaker :class, threshold: 1, cool_off: 60
    end
    child = create_task_class(base: parent, name: "ChildSkuBreaker") do
      circuit_breaker :sku
      required :sku, coerce: :string

      define_method(:work) { raise err }
    end

    child.execute(sku: "A")
    expect(child.execute(sku: "A").metadata[:code]).to eq(:circuit_open)
    expect(child.execute(sku: "B")).to be_ko
  end

  context "with retry_on" do
    it "counts one failure per invocation after retries exhaust" do
      attempts = 0
      klass = create_task_class(name: "FlakyBreaker") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        retry_on CMDx::TestError, limit: 2, delay: 0
        required :sku, coerce: :string

        define_method(:work) do
          attempts += 1
          raise CMDx::TestError
        end
      end

      2.times { klass.execute(sku: "A") }
      result = klass.execute(sku: "A")

      expect(attempts).to eq(6)
      expect(result.metadata[:code]).to eq(:circuit_open)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Task rate_limit", type: :feature do
  it "inherits configuration from the superclass" do
    parent = create_task_class(name: "ParentRate") do
      rate_limit :class, max: 9, per: 60
    end
    child = create_task_class(base: parent, name: "ChildRate") do
      required :email, coerce: :string

      define_method(:work) { nil }
    end

    expect(child.rate_limit.max).to eq(9)
  end

  it "can be disabled on a subclass" do
    parent = create_task_class(name: "ParentRateOn") do
      rate_limit :class, max: 0, per: 60
    end
    child = create_task_class(base: parent, name: "ChildRateOff") do
      rate_limit false
      required :email, coerce: :string

      define_method(:work) { context.runs = 1 }
    end

    expect(child.rate_limit).not_to be_enabled
    expect(child.execute(email: "a@example.com")).to be_ok
  end

  it "does not consume quota on retry attempts" do
    err = Class.new(StandardError)
    attempts = 0
    klass = create_task_class(name: "RetryRateTask") do
      rate_limit :email, max: 2, per: 60
      retry_on err, limit: 3, delay: 0
      required :email, coerce: :string

      define_method(:work) do
        attempts += 1
        raise err if attempts < 3

        context.ok = true
      end
    end

    result = klass.execute(email: "u@example.com")

    expect(result).to be_ok
    expect(attempts).to eq(3)
    expect(CMDx::Stores.get("cmdx:rl:#{klass.name}:u@example.com")).to eq("1")
  end

  it "rate limits before the circuit breaker runs" do
    err = Class.new(StandardError)
    klass = create_task_class(name: "RateBeforeBreaker") do
      rate_limit :class, max: 1, per: 60
      circuit_breaker :class, threshold: 1, cool_off: 60
      required :sku, coerce: :string

      define_method(:work) { raise err }
    end

    klass.execute(sku: "A")
    result = klass.execute(sku: "A")

    expect(result.metadata[:code]).to eq(:rate_limited)
    expect(result.metadata[:code]).not_to eq(:circuit_open)
  end
end

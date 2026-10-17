# frozen_string_literal: true

RSpec.describe "Task idempotency", type: :feature do
  it "inherits idempotent_by from the superclass" do
    parent = create_task_class(name: "ParentIdem") do
      idempotent_by :request_id, ttl: 120
    end
    child = create_task_class(base: parent, name: "ChildIdem") do
      required :request_id, coerce: :string

      define_method(:work) { nil }
    end

    expect(child.idempotent_by.ttl).to eq(120)
  end

  it "can be disabled on a subclass" do
    parent = create_task_class(name: "ParentIdemEnabled") do
      idempotent_by :payment_id
    end
    child = create_task_class(base: parent, name: "ChildIdemDisabled") do
      idempotent_by false
      required :payment_id, coerce: :string

      define_method(:work) { context.touched = true }
    end

    expect(child.idempotent_by).not_to be_enabled
    child.execute(payment_id: "pay-1")
    result = child.execute(payment_id: "pay-1")

    expect(result).to be_ok
    expect(result.context.touched).to be(true)
  end

  it "lets subclasses override the key resolver" do
    parent = create_task_class(name: "ParentKey") do
      idempotent_by :parent_id
    end
    child = create_task_class(base: parent, name: "ChildKey") do
      idempotent_by :child_id
      required :child_id, coerce: :string

      define_method(:work) { context.touched = true }
    end

    child.execute(child_id: "c-1")
    result = child.execute(child_id: "c-1")

    expect(result).to be_skipped
  end

  context "with retry_on" do
    it "releases the claim on failure so retries can run work again" do
      attempts = 0
      klass = create_task_class(name: "FlakyIdem") do
        idempotent_by :payment_id
        retry_on CMDx::TestError, limit: 2, delay: 0
        required :payment_id, coerce: :string

        define_method(:work) do
          attempts += 1
          raise CMDx::TestError if attempts < 3

          context.charged = true
        end
      end

      result = klass.execute(payment_id: "pay_retry")

      expect(result).to be_ok
      expect(attempts).to eq(3)
      expect(klass.execute(payment_id: "pay_retry")).to be_skipped
    end
  end
end

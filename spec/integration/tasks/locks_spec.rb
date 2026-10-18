# frozen_string_literal: true

RSpec.describe "Task locks", type: :feature do
  it "inherits lock_with from the superclass" do
    parent = create_task_class(name: "ParentLock") do
      lock_with :request_id, ttl: 120
    end
    child = create_task_class(base: parent, name: "ChildLock") do
      required :request_id, coerce: :string

      define_method(:work) { nil }
    end

    expect(child.lock_with.ttl).to eq(120)
  end

  it "replaces the lock key on a subclass while merging options" do
    parent = create_task_class(name: "ParentLockMerge") do
      lock_with :tenant_id, ttl: 600
    end
    child = create_task_class(base: parent, name: "ChildLockMerge") do
      lock_with :account_id
      required :account_id, coerce: :string

      define_method(:work) { nil }
    end

    expect(child.lock_with.key).to eq(:account_id)
    expect(child.lock_with.ttl).to eq(600)
  end

  it "can be disabled on a subclass" do
    parent = create_task_class(name: "ParentLockEnabled") do
      lock_with :resource_id
    end
    child = create_task_class(base: parent, name: "ChildLockDisabled") do
      lock_with false
      required :resource_id, coerce: :string

      define_method(:work) { context.touched = true }
    end

    expect(child.lock_with).not_to be_enabled
    child.execute(resource_id: "r-1")
    result = child.execute(resource_id: "r-1")

    expect(result).to be_ok
    expect(result.context.touched).to be(true)
  end

  it "releases the lease when work signals skip!" do
    attempts = 0
    klass = create_task_class(name: "LockSkipRelease") do
      lock_with :resource_id
      required :resource_id, coerce: :string

      define_method(:work) do
        attempts += 1
        skip!("noop") if attempts == 1
      end
    end

    expect(klass.execute(resource_id: "r-1")).to be_skipped
    expect(klass.execute(resource_id: "r-1")).to be_ok
  end

  it "pairs with idempotent_by so a repeat invocation skips" do
    klass = create_task_class(name: "LockAndIdem") do
      lock_with :resource_id
      idempotent_by :resource_id
      required :resource_id, coerce: :string

      define_method(:work) { context.done = true }
    end

    expect(klass.execute(resource_id: "combo")).to be_ok
    result = klass.execute(resource_id: "combo")

    expect(result).to be_skipped
    expect(result.metadata[:code]).to eq(:duplicate)
  end

  it "releases the lease when work signals fail!" do
    attempts = 0
    klass = create_task_class(name: "LockFailRelease") do
      lock_with :resource_id
      required :resource_id, coerce: :string

      define_method(:work) do
        attempts += 1
        fail!("nope") if attempts == 1

        context.touched = true
      end
    end

    expect(klass.execute(resource_id: "r-1")).to be_ko

    result = klass.execute(resource_id: "r-1")

    expect(result).to be_ok
    expect(result.context.touched).to be(true)
  end

  context "with retry_on" do
    it "holds the lease across retry attempts so concurrent runs stay busy" do
      attempts = 0
      busy_codes = []
      klass = create_task_class(name: "LockRetryHold") do
        lock_with :resource_id, on_busy: :fail
        retry_on CMDx::TestError, limit: 2, delay: 0.05
        required :resource_id, coerce: :string

        define_method(:work) do
          attempts += 1
          if attempts == 1
            Thread.new { busy_codes << klass.execute(resource_id: "r").metadata[:code] }.join
            raise CMDx::TestError
          end

          context.done = true
        end
      end

      result = klass.execute(resource_id: "r")

      expect(result).to be_ok
      expect(attempts).to eq(2)
      expect(busy_codes).to eq([:busy])
      expect(klass.execute(resource_id: "r")).to be_ok
    end
  end
end

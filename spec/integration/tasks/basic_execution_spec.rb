# frozen_string_literal: true

require "spec_helper"

# Integration-style examples across Task, Runtime, and middleware.
RSpec.describe "CMDx task integration", :integration do # rubocop:disable RSpec/DescribeClass
  it "simple task succeeds" do
    k = Class.new(CMDx::Task) do
      def work
        ctx[:x] = 1
      end
    end
    r = k.execute
    expect(r.success?).to be(true)
    expect(r.context[:x]).to eq(1)
  end

  it "task with attributes validates and coerces" do
    k = Class.new(CMDx::Task) do
      required :n, :integer
      def work
        ctx[:doubled] = n * 2
      end
    end
    r = k.execute(n: "4")
    expect(r.success?).to be(true)
    expect(r.context[:doubled]).to eq(8)
  end

  it "task with fail! returns failed result" do
    k = Class.new(CMDx::Task) do
      def work
        fail!("no", halt: true)
      end
    end
    r = k.execute
    expect(r.failed?).to be(true)
    expect(r.status).to eq("failed")
  end

  it "task with skip! returns skipped result" do
    k = Class.new(CMDx::Task) do
      def work
        skip!("later", halt: true)
      end
    end
    r = k.execute
    expect(r.skipped?).to be(true)
    expect(r.status).to eq("skipped")
  end

  it "task with callbacks fires in correct order" do
    log = []
    k = Class.new(CMDx::Task) do
      required :v, :integer
      before_validation { log << :bv }
      before_execution { log << :be }
      on_success { log << :os }
      on_complete { log << :oc }
      on_executed { log << :ex }
      define_method(:work) { log << :w }
    end
    k.execute(v: 1)
    expect(log).to eq(%i[bv be w os oc ex])
  end

  it "task with middleware wraps execution" do
    mw = Module.new do
      def self.call(task, *)
        task.ctx[:mw] = true
        yield
      end
    end
    k = Class.new(CMDx::Task) do
      register mw
      def work; end
    end
    r = k.execute
    expect(r.context[:mw]).to be(true)
  end

  it "task with returns verifies context keys" do
    k = Class.new(CMDx::Task) do
      returns :token
      def work; end
    end
    expect(k.execute.failed?).to be(true)
    ok = Class.new(k) do
      def work
        ctx[:token] = "abc"
      end
    end
    expect(ok.execute.success?).to be(true)
  end

  it "task with retries retries on exception" do
    tries = [0]
    k = Class.new(CMDx::Task) do
      settings do |s|
        s.retry_count = 1
        s.retry_delay = 0
        s.retry_jitter = 0
        s.retry_on = [RuntimeError]
      end
      define_method(:work) do
        tries[0] += 1
        raise "x" if tries[0] < 2
      end
    end
    r = k.execute
    expect(r.success?).to be(true)
    expect(r.retries).to eq(1)
  end

  it "task with rollback calls rollback on failure" do
    rb = [false]
    k = Class.new(CMDx::Task) do
      define_method(:rollback) { rb[0] = true }
      def work
        fail!("x", halt: true)
      end
    end
    k.execute
    expect(rb[0]).to be(true)
  end

  it "execute! raises FailFault or SkipFault" do
    f = Class.new(CMDx::Task) { def work = fail!("f", halt: true) }
    expect { f.execute! }.to raise_error(CMDx::FailFault)
    s = Class.new(CMDx::Task) { def work = skip!("s", halt: true) }
    expect { s.execute! }.to raise_error(CMDx::SkipFault)
  end

  it "dry_run: true in context is visible on result" do
    k = Class.new(CMDx::Task) { def work; end }
    r = k.execute(dry_run: true)
    expect(r.dry_run?).to be(true)
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::RateLimit do
  let(:task_class) do
    create_task_class(name: "RateLimitTask") do
      required :email, coerce: :string

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
      base = described_class.new(:class, max: 3, per: 60)
      built = base.build(:email, max: 5, per: 120)

      expect(built.key).to eq(:email)
      expect(built.max).to eq(5)
      expect(built.per).to eq(120)
    end

    it "enables with :class when only options are passed on a disabled config" do
      built = described_class.disabled.build(nil, max: 2, per: 30)

      expect(built).to be_enabled
      expect(built.key).to eq(:class)
      expect(built.max).to eq(2)
    end

    it "returns self when nothing changes" do
      config = described_class.new(:class, max: 1, per: 10)
      expect(config.build(nil, {})).to be(config)
    end
  end

  describe "#process" do
    it "runs work when disabled" do
      task = task_class.new(email: "a@example.com")
      config = described_class.disabled

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "fails when fixed-window max is exceeded" do
      klass = create_task_class(name: "FixedWindowTask") do
        rate_limit :email, max: 2, per: 60, limiter: :fixed_window
        required :email, coerce: :string

        define_method(:work) { context.ok = true }
      end

      klass.execute(email: "u@example.com")
      klass.execute(email: "u@example.com")
      result = klass.execute(email: "u@example.com")

      expect(result).to be_ko
      expect(result.metadata[:code]).to eq(:rate_limited)
      expect(result.metadata[:count]).to eq(3)
      expect(result.metadata[:limiter]).to eq(:fixed_window)
    end

    it "scopes limits per resolved key segment" do
      klass = create_task_class(name: "ScopedRateTask") do
        rate_limit :email, max: 1, per: 60
        required :email, coerce: :string

        define_method(:work) { nil }
      end

      expect(klass.execute(email: "a@example.com")).to be_ok
      expect(klass.execute(email: "b@example.com")).to be_ok
      expect(klass.execute(email: "a@example.com")).to be_ko
    end

    it "skips when on_limit is :skip" do
      klass = create_task_class(name: "SkipRateTask") do
        rate_limit :email, max: 1, per: 60, on_limit: :skip
        required :email, coerce: :string

        define_method(:work) { context.runs = 1 }
      end

      klass.execute(email: "a@example.com")
      result = klass.execute(email: "a@example.com")

      expect(result).to be_skipped
      expect(result.metadata[:code]).to eq(:rate_limited)
      expect(result.context.runs).to be_nil
    end

    it "emits telemetry when subscribed" do
      events = []
      klass = create_task_class(name: "TelemetryRateTask") do
        rate_limit :email, max: 1, per: 60
        required :email, coerce: :string

        define_method(:work) { nil }
      end
      klass.telemetry.subscribe(:rate_limit_admitted) { |e| events << e }
      klass.telemetry.subscribe(:rate_limit_exceeded) { |e| events << e }

      klass.execute(email: "u@example.com")
      klass.execute(email: "u@example.com")

      expect(events.map(&:name)).to eq(%i[rate_limit_admitted rate_limit_exceeded])
      expect(events.first.payload[:rate_limit_key]).to eq("cmdx:rl:#{klass.name}:u@example.com")
    end

    it "uses leaky_bucket limiter" do
      klass = create_task_class(name: "LeakyTask") do
        rate_limit :class, max: 1, per: 60, limiter: :leaky_bucket
        required :email, coerce: :string

        define_method(:work) { nil }
      end

      expect(klass.execute(email: "a@example.com")).to be_ok
      result = klass.execute(email: "a@example.com")
      expect(result).to be_ko
      expect(result.metadata[:limiter]).to eq(:leaky_bucket)
      expect(result.metadata[:level]).to be_a(Float)
    end
  end
end

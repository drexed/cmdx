# frozen_string_literal: true

RSpec.describe "Task input resolution", type: :feature do
  describe "presence rules" do
    let(:task) do
      create_task_class(name: "PresenceTask") do
        required :email
        optional :name

        define_method(:work) { nil }
      end
    end

    it "succeeds when required keys are present (optional missing is fine)" do
      expect(task.execute(email: "a@b.c")).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "fails when a required key is absent" do
      result = task.execute(name: "Alice")

      expect(result).to have_attributes(status: CMDx::Signal::FAILED)
      expect(result.errors.to_h).to eq(email: ["is required"])
    end

    it "collects errors for every missing required key" do
      result = create_task_class(name: "MultiRequired") do
        required :email, :name
        define_method(:work) { nil }
      end.execute

      expect(result.errors.to_h.keys).to contain_exactly(:email, :name)
    end

    it "passes the required check for an explicit nil value" do
      expect(task.execute(email: nil).errors.to_h).not_to have_key(:email)
    end

    it "raises a Fault under execute!" do
      expect { task.execute! }.to raise_error(CMDx::Fault, /email is required/)
    end
  end

  describe "conditional required" do
    let(:task) do
      create_task_class(name: "ConditionalRequired") do
        required :publisher, if: :magazine?
        required :title

        define_method(:work) { nil }
        define_method(:magazine?) { context[:type] == "magazine" }
      end
    end

    it "requires the key when condition is true" do
      result = task.execute(title: "Issue 1", type: "magazine")

      expect(result.errors.to_h).to include(publisher: ["is required"])
    end

    it "treats the key as optional when condition is false" do
      expect(task.execute(title: "Blog", type: "blog"))
        .to have_attributes(status: CMDx::Signal::SUCCESS)
    end
  end

  describe "coercion" do
    it "coerces to the declared type and exposes the coerced value" do
      task = create_task_class(name: "CoerceTask") do
        input :count, coerce: :integer
        input :active, coerce: :boolean
        define_method(:work) do
          context.resolved = [count, active]
        end
      end

      result = task.execute(count: "42", active: "yes")

      expect(result.context[:resolved]).to eq([42, true])
    end

    it "fails when coercion cannot succeed" do
      task = create_task_class(name: "CoerceFail") do
        input :count, coerce: :integer
        define_method(:work) { nil }
      end

      result = task.execute(count: "abc")

      expect(result.errors.to_h[:count].first).to include("integer")
    end

    it "leaves the backing ivar at nil when coercion fails" do
      klass = create_task_class(name: "CoerceFailIvar") do
        input :count, coerce: :integer
        define_method(:work) { nil }
      end

      instance = klass.new(count: "abc")
      instance.execute

      expect(instance.instance_variable_get(:@_input_count)).to be_nil
    end

    it "falls back through a multi-type list" do
      task = create_task_class(name: "MultiCoerce") do
        input :value, coerce: %i[integer float]
        define_method(:work) { context.resolved = value }
      end

      expect(task.execute(value: "3.14").context[:resolved]).to eq(3.14)
    end

    it "threads per-type options to the coercer" do
      task = create_task_class(name: "OptionedCoerce") do
        input :recorded_at, coerce: { date: { strptime: "%m-%d-%Y" } }
        define_method(:work) { context.resolved = recorded_at }
      end

      expect(task.execute(recorded_at: "01-23-2024").context[:resolved])
        .to eq(Date.new(2024, 1, 23))
    end

    describe "inline :coerce callables" do
      it "invokes a Symbol handler with the value on the task" do
        task = create_task_class(name: "InlineSymbolCoerce") do
          input :value, coerce: :double_it
          define_method(:work) { context.resolved = value }
          define_method(:double_it) { |v| v.to_i * 2 }
        end

        expect(task.execute(value: "21").context[:resolved]).to eq(42)
      end

      it "invokes a Proc handler via instance_exec, exposing self as the task" do
        task = create_task_class(name: "InlineProcCoerce") do
          input :value, coerce: ->(v) { v.to_f * tax_rate }
          define_method(:work) { context.resolved = value }
          define_method(:tax_rate) { 1.5 }
        end

        expect(task.execute(value: "10").context[:resolved]).to eq(15.0)
      end

      it "invokes a class callable with (value, task)" do
        coercer = Class.new do
          def self.call(value, task)
            multiplier = task.context.multiplier || 1
            value.to_i * multiplier
          end
        end

        task = create_task_class(name: "InlineClassCoerce") do
          input :value, coerce: coercer
          define_method(:work) { context.resolved = value }
        end

        expect(task.execute(value: "5", multiplier: 3).context[:resolved]).to eq(15)
      end

      it "falls through to an inline callable when the prior built-in coercion fails" do
        task = create_task_class(name: "InlineFallbackCoerce") do
          input :value, coerce: [:integer, ->(v) { "fallback:#{v}" }]
          define_method(:work) { context.resolved = value }
        end

        expect(task.execute(value: "abc").context[:resolved]).to eq("fallback:abc")
      end
    end

    it "supports custom registered coercions with options" do
      task = create_task_class(name: "CustomCoerce") do
        register :coercion, :temperature, proc { |v, unit: :celsius, **|
          value = v.to_f
          unit == :fahrenheit ? (value * 9.0 / 5.0) + 32.0 : value
        }
        input :temp, coerce: { temperature: { unit: :fahrenheit } }
        define_method(:work) { context.resolved = temp }
      end

      expect(task.execute(temp: 100).context[:resolved]).to eq(212.0)
    end
  end

  describe "defaults" do
    it "uses a static default when the key is absent" do
      task = create_task_class(name: "Default") do
        input :level, default: "basic"
        define_method(:work) { context.resolved = level }
      end

      expect(task.execute.context[:resolved]).to eq("basic")
    end

    it "evaluates a callable default lazily" do
      task = create_task_class(name: "CallableDefault") do
        input :stamp, default: proc { Time.now.to_i }
        define_method(:work) { context.resolved = stamp }
      end

      expect(task.execute.context[:resolved]).to be_a(Integer)
    end

    it "prefers the provided value over the default" do
      task = create_task_class(name: "PreferProvided") do
        input :level, default: "basic"
        define_method(:work) { context.resolved = level }
      end

      expect(task.execute(level: "advanced").context[:resolved]).to eq("advanced")
    end

    it "enforces the required check before applying the default" do
      task = create_task_class(name: "RequiredDefault") do
        required :token, default: "fallback"
        define_method(:work) { context.resolved = token }
      end

      expect(task.execute.errors.to_h).to include(token: ["is required"])
      expect(task.execute(token: nil).context[:resolved]).to eq("fallback")
    end
  end

  describe "transform" do
    it "applies a Symbol transform" do
      task = create_task_class(name: "SymbolTransform") do
        input :email, transform: :downcase
        define_method(:work) { context.resolved = email }
      end

      expect(task.execute(email: "USER@TEST.COM").context[:resolved]).to eq("user@test.com")
    end

    it "applies a Proc transform after coercion, in the task instance" do
      task = create_task_class(name: "ProcTransform") do
        input :amount, coerce: :float, transform: ->(v) { v * tax_rate }
        define_method(:work) { context.resolved = amount }
        define_method(:tax_rate) { 1.08 }
      end

      expect(task.execute(amount: "100").context[:resolved]).to be_within(0.01).of(108.0)
    end
  end

  describe "validations" do
    it "runs built-in validators" do
      task = create_task_class(name: "Validated") do
        input :title, presence: true, length: { min: 3, max: 50 }
        define_method(:work) { nil }
      end

      expect(task.execute(title: "AB").errors.to_h[:title]).not_to be_empty
      expect(task.execute(title: "ok title")).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "validates after coerce and transform" do
      task = create_task_class(name: "FullPipeline") do
        input :frequency,
          coerce: :string,
          transform: :downcase,
          inclusion: { in: %w[hourly daily weekly monthly] }
        define_method(:work) { context.resolved = frequency }
      end

      expect(task.execute(frequency: "DAILY").context[:resolved]).to eq("daily")
      expect(task.execute(frequency: "BIWEEKLY").errors.to_h).to include(:frequency)
    end

    it "leaves the backing ivar at nil when a validator fails" do
      klass = create_task_class(name: "ValidateFailIvar") do
        input :age, coerce: :integer, numeric: { min: 18 }
        define_method(:work) { nil }
      end

      instance = klass.new(age: "5")
      instance.execute

      expect(instance.instance_variable_get(:@_input_age)).to be_nil
      expect(instance.errors.to_h[:age]).not_to be_empty
    end

    describe "inline :validate callables" do
      it "invokes a Symbol handler with the value on the task" do
        task = create_task_class(name: "InlineSymbolValidate") do
          input :slug, validate: :reject_reserved
          define_method(:work) { context.resolved = slug }
          define_method(:reject_reserved) do |v|
            CMDx::Validators::Failure.new("is reserved") if v == "admin"
          end
        end

        expect(task.execute(slug: "alice")).to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(task.execute(slug: "admin").errors.to_h[:slug]).to include("is reserved")
      end

      it "invokes a Proc handler via instance_exec, exposing self as the task" do
        task = create_task_class(name: "InlineProcValidate") do
          input :slug, validate: lambda { |v|
            CMDx::Validators::Failure.new("bad") unless v.size >= min_size
          }
          define_method(:work) { context.resolved = slug }
          define_method(:min_size) { 4 }
        end

        expect(task.execute(slug: "okok")).to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(task.execute(slug: "no").errors.to_h[:slug]).to include("bad")
      end

      it "invokes a class callable with (value, task)" do
        validator = Class.new do
          def self.call(value, task)
            return unless task.context.reserved.include?(value)

            CMDx::Validators::Failure.new("is reserved")
          end
        end

        task = create_task_class(name: "InlineClassValidate") do
          input :handle, validate: validator
          define_method(:work) { context.resolved = handle }
        end

        expect(task.execute(handle: "alice", reserved: %w[root admin]))
          .to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(task.execute(handle: "root", reserved: %w[root admin]).errors.to_h[:handle])
          .to include("is reserved")
      end

      it "runs every handler in an array and accumulates failures" do
        task = create_task_class(name: "InlineChainValidate") do
          input :slug, validate: [
            ->(v) { CMDx::Validators::Failure.new("must be lowercase") if v != v.downcase },
            ->(v) { CMDx::Validators::Failure.new("too short") if v.size < 3 }
          ]
          define_method(:work) { nil }
        end

        result = task.execute(slug: "AB")
        expect(result.errors.to_h[:slug]).to include("must be lowercase", "too short")
      end
    end

    it "supports custom registered validators returning Failure" do
      task = create_task_class(name: "CustomValidator") do
        register :validator, :api_key, proc { |v, **|
          CMDx::Validators::Failure.new("invalid API key format") unless v.to_s.match?(/\A[a-z0-9]{32}\z/)
        }
        input :access_key, api_key: true
        define_method(:work) { nil }
      end

      expect(task.execute(access_key: "a" * 32)).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(task.execute(access_key: "short").errors.to_h[:access_key])
        .to include("invalid API key format")
    end
  end

  describe "naming" do
    it "renames readers via prefix, suffix, and as:" do
      task = create_task_class(name: "Naming") do
        input :format, prefix: "report_"
        input :version, suffix: "_tag"
        input :scheduled_at, as: :due_date
        define_method(:work) do
          context.resolved = [report_format, version_tag, due_date]
        end
      end

      result = task.execute(format: "pdf", version: "v1.2.3", scheduled_at: "2024-12-15")

      expect(result.context[:resolved]).to eq(["pdf", "v1.2.3", "2024-12-15"])
    end
  end

  describe "nested inputs" do
    let(:task) do
      create_task_class(name: "Nested") do
        required :network do
          required :host, :port
          optional :protocol
        end

        define_method(:work) do
          context.resolved = [host, port, protocol]
        end
      end
    end

    it "resolves parent and children together" do
      result = task.execute(network: { host: "api.example.com", port: 443, protocol: "https" })

      expect(result.context[:resolved]).to eq(["api.example.com", 443, "https"])
    end

    it "fails when the parent is missing" do
      expect(task.execute.errors.to_h).to include(:network)
    end

    it "fails when a required child is missing" do
      result = task.execute(network: { host: "api.example.com" })

      expect(result.errors.to_h).to include(:port)
    end

    it "preserves falsy child values when the parent is present" do
      result = task.execute(network: { host: "h", port: 1, protocol: nil })

      expect(result.context[:resolved]).to eq(["h", 1, nil])
    end
  end

  describe "inheritance" do
    let(:parent) do
      create_task_class(name: "ParentInputs") do
        required :tenant_id
        define_method(:work) { nil }
      end
    end

    it "inherits parent inputs alongside its own" do
      child = create_task_class(base: parent, name: "ChildInputs") do
        required :user_id
        define_method(:work) { nil }
      end

      expect(child.execute(tenant_id: "t", user_id: "u"))
        .to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(child.execute(user_id: "u").errors.to_h).to include(:tenant_id)
    end

    it "deregisters inherited inputs via deregister" do
      child = create_task_class(base: parent, name: "ChildRemove") do
        deregister :input, :tenant_id
        define_method(:work) { nil }
      end

      expect(child.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(child.inputs.registry).not_to have_key(:tenant_id)
    end
  end

  describe "source option" do
    it "resolves from a Symbol method" do
      task = create_task_class(name: "SourceMethod") do
        input :host, source: :server_config
        define_method(:work) { context.resolved = host }
        define_method(:server_config) { { host: "db.example.com" } }
      end

      expect(task.execute.context[:resolved]).to eq("db.example.com")
    end

    it "resolves from a Proc" do
      task = create_task_class(name: "SourceProc") do
        input :stamp, source: proc { Time.now.to_i }
        define_method(:work) { context.resolved = stamp }
      end

      expect(task.execute.context[:resolved]).to be_a(Integer)
    end

    it "resolves from a Struct as the source value" do
      config = Struct.new(:host, :port, keyword_init: true)
      task = create_task_class(name: "SourceStruct") do
        required :host, source: :cfg
        required :port, source: :cfg
        define_method(:work) { context.resolved = [host, port] }
        define_method(:cfg) { config.new(host: "h", port: 5432) }
      end

      expect(task.execute.context[:resolved]).to eq(["h", 5432])
    end

    it "falls back to string keys inside the source" do
      task = create_task_class(name: "StringKeys") do
        input :enabled, source: :params
        define_method(:work) { context.resolved = enabled }
        define_method(:params) { { "enabled" => false } }
      end

      expect(task.execute.context[:resolved]).to be(false)
    end

    it "fails with a helpful message for an unsupported source type" do
      task = create_task_class(name: "BadSource") do
        input :name, source: 42
        define_method(:work) { nil }
      end

      expect(task.execute(name: "Alice").reason)
        .to include("must be a Symbol, Proc, or respond to #call")
      expect { task.execute!(name: "Alice") }.to raise_error(ArgumentError)
    end
  end

  describe "falsy values" do
    let(:task) do
      create_task_class(name: "Falsy") do
        required :flag
        input :count, coerce: :integer
        define_method(:work) { context.resolved = [flag, count] }
      end
    end

    it "preserves false as a valid value" do
      expect(task.execute(flag: false, count: 0).context[:resolved]).to eq([false, 0])
    end

    it "passes the required check for an explicit nil" do
      expect(task.execute(flag: nil).errors.to_h).not_to have_key(:flag)
    end
  end

  describe "inputs_schema" do
    it "serializes the declared inputs" do
      task = create_task_class(name: "Schema") do
        required :email, coerce: :string, format: /\A.+@.+\z/
        optional :role, default: "member", inclusion: { in: %w[member admin] }
      end

      schema = task.inputs_schema

      expect(schema[:email]).to include(required: true, options: hash_including(coerce: :string))
      expect(schema[:role]).to include(required: false, options: hash_including(default: "member"))
    end
  end
end

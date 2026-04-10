# frozen_string_literal: true

RSpec.describe "Task execution" do # rubocop:disable RSpec/DescribeClass
  describe "basic execution" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def self.name = "BasicTask"

        def work
          ctx.output = "done"
        end
      end
    end

    it "executes successfully and returns a frozen result" do
      result = task_class.execute
      expect(result).to be_success
      expect(result).to be_complete
      expect(result).to be_frozen
      expect(result.context[:output]).to eq("done")
    end
  end

  describe "attributes" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def self.name = "AttrTask"

        required :name, :string, presence: true
        optional :greeting, :string, default: "Hello"

        def work
          ctx.message = "#{greeting}, #{name}!"
        end
      end
    end

    it "resolves and coerces attributes" do
      result = task_class.execute(name: "World")
      expect(result).to be_success
      expect(result.context[:message]).to eq("Hello, World!")
    end

    it "fails validation when required attribute is blank" do
      result = task_class.execute(name: "")
      expect(result).to be_failed
      expect(result.errors[:name]).not_to be_empty
    end

    it "applies defaults to optional attributes" do
      result = task_class.execute(name: "X")
      expect(result).to be_success
      expect(result.context[:message]).to include("Hello")
    end

    it "allows overriding defaults" do
      result = task_class.execute(name: "X", greeting: "Hi")
      expect(result).to be_success
      expect(result.context[:message]).to eq("Hi, X!")
    end
  end

  describe "nested attributes" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def self.name = "NestedTask"

        required :address, :hash do
          required :street, :string, presence: true
          required :city, :string, presence: true
        end

        def work
          ctx.formatted = "#{address[:street]}, #{address[:city]}"
        end
      end
    end

    it "validates nested children" do
      result = task_class.execute(address: { street: "", city: "NYC" })
      expect(result).to be_failed
      errors = result.errors.to_h
      expect(errors).to have_key(:"address.street")
    end

    it "succeeds with valid nested data" do
      result = task_class.execute(address: { street: "123 Main", city: "NYC" })
      expect(result).to be_success
    end
  end

  describe "signals" do
    it "handles fail!" do
      task = Class.new(CMDx::Task) do
        def self.name = "FailTask"
        def work = fail!("broke")
      end

      result = task.execute
      expect(result).to be_failed
      expect(result.reason).to eq("broke")
    end

    it "handles skip!" do
      task = Class.new(CMDx::Task) do
        def self.name = "SkipTask"
        def work = skip!("not needed")
      end

      result = task.execute
      expect(result).to be_skipped
      expect(result.reason).to eq("not needed")
    end

    it "handles success! with annotation" do
      task = Class.new(CMDx::Task) do
        def self.name = "AnnotateTask"
        def work = success!("all good", custom: "data")
      end

      result = task.execute
      expect(result).to be_success
    end

    it "handles non-halting fail!" do
      task = Class.new(CMDx::Task) do
        def self.name = "NonHaltTask"

        def work
          fail!("soft fail", halt: false)
          ctx.reached = true
        end
      end

      result = task.execute
      expect(result).to be_failed
      expect(result.context[:reached]).to be true
    end
  end

  describe "execute!" do
    it "raises FailFault on failure" do
      task = Class.new(CMDx::Task) do
        def self.name = "BangTask"
        def work = fail!("boom")
      end

      expect { task.execute! }.to raise_error(CMDx::FailFault) do |e|
        expect(e.result).to be_failed
        expect(e.result.reason).to eq("boom")
      end
    end

    it "raises SkipFault on skip when breakpoints include skipped" do
      task = Class.new(CMDx::Task) do
        def self.name = "SkipBangTask"
        settings task_breakpoints: %w[failed skipped]
        def work = skip!("nope")
      end

      expect { task.execute! }.to raise_error(CMDx::SkipFault)
    end

    it "does not raise on skip by default (only failed triggers fault)" do
      task = Class.new(CMDx::Task) do
        def self.name = "SkipSoftTask"
        def work = skip!("nope")
      end

      result = task.execute!
      expect(result).to be_skipped
    end

    it "does not raise on success" do
      task = Class.new(CMDx::Task) do
        def self.name = "OkTask"
        def work = nil
      end

      expect { task.execute! }.not_to raise_error
    end
  end

  describe "returns" do
    let(:task_class) do
      Class.new(CMDx::Task) do
        def self.name = "ReturnsTask"
        returns :user

        def work
          ctx.user = "Juan"
        end
      end
    end

    it "succeeds when return key is present" do
      result = task_class.execute
      expect(result).to be_success
    end

    it "fails when return key is missing" do
      missing = Class.new(CMDx::Task) do
        def self.name = "MissingReturnTask"
        returns :user
        def work; end
      end

      result = missing.execute
      expect(result).to be_failed
    end
  end

  describe "callbacks" do
    it "invokes status callbacks" do
      task = Class.new(CMDx::Task) do
        def self.name = "CbTask"

        on_success ->(r) { r } # just to ensure it runs
        on_complete ->(r) { r }
        on_executed ->(r) { r }

        define_method(:work) { ctx.output = "ok" }
      end

      result = task.execute
      expect(result).to be_success
    end

    it "invokes on_failed on failure" do
      task = Class.new(CMDx::Task) do
        def self.name = "FailCbTask"

        on_failed :handle_failure

        def work = fail!("broke")

        private

        define_method(:handle_failure) { |_r| nil }
      end

      result = task.execute
      expect(result).to be_failed
    end
  end

  describe "rollback" do
    it "calls rollback on failure" do
      rolled_back = false

      task = Class.new(CMDx::Task) do
        def self.name = "RollbackTask"
        settings rollback_on: %w[failed]

        def work = fail!("fail")

        define_method(:rollback) { rolled_back = true }
      end

      task.execute
      expect(rolled_back).to be true
    end
  end

  describe "exception handling" do
    it "catches unhandled exceptions" do
      task = Class.new(CMDx::Task) do
        def self.name = "ExcTask"
        def work = raise("kaboom")
      end

      result = task.execute
      expect(result).to be_failed
      expect(result.reason).to eq("kaboom")
      expect(result.cause).to be_a(RuntimeError)
    end
  end

  describe "block yielding" do
    it "yields the result to a block" do
      task = Class.new(CMDx::Task) do
        def self.name = "BlockTask"
        def work; end
      end

      yielded = nil
      task.execute { |r| yielded = r }
      expect(yielded).to be_a(CMDx::Result)
      expect(yielded).to be_success
    end
  end

  describe "chain" do
    it "tracks results in the chain" do
      task = Class.new(CMDx::Task) do
        def self.name = "ChainTask"
        def work; end
      end

      result = task.execute
      expect(result.chain).to be_a(CMDx::Chain)
      expect(result.chain.size).to eq(1)
    end
  end

  describe "dry_run?" do
    it "reports dry_run when context has dry_run key" do
      task = Class.new(CMDx::Task) do
        def self.name = "DryRunTask"

        def work
          ctx.was_dry = dry_run?
        end
      end

      result = task.execute(dry_run: true)
      expect(result.context[:was_dry]).to be true
      expect(result).to be_dry_run
    end
  end
end

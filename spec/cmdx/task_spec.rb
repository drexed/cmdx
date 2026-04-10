# frozen_string_literal: true

RSpec.describe CMDx::Task do
  before { CMDx.configuration.freeze_results = false }

  describe ".execute" do
    it "executes a minimal task" do
      klass = Class.new(described_class) do
        def work
          context.done = true
        end
      end

      result = klass.execute
      expect(result).to be_success
      expect(result.context.done).to be(true)
    end

    it "raises UndefinedMethodError without work" do
      klass = Class.new(described_class)
      result = klass.execute
      expect(result).to be_failed
      expect(result.reason).to include("must define a `work` method")
    end

    it "accepts a block" do
      klass = Class.new(described_class) do
        def work; end
      end

      yielded = nil
      klass.execute { |r| yielded = r }
      expect(yielded).to be_success
    end
  end

  describe ".execute!" do
    it "raises FailFault on failure" do
      klass = Class.new(described_class) do
        def work
          fail!("broken")
        end
      end

      expect { klass.execute! }.to raise_error(CMDx::FailFault, "broken")
    end

    it "raises SkipFault on skip when configured" do
      klass = Class.new(described_class) do
        settings(task_breakpoints: %w[skipped failed])

        def work
          skip!("not needed")
        end
      end

      expect { klass.execute! }.to raise_error(CMDx::SkipFault, "not needed")
    end

    it "returns result on success" do
      klass = Class.new(described_class) do
        def work
          context.x = 1
        end
      end

      result = klass.execute!
      expect(result).to be_success
    end
  end

  describe "attributes" do
    it "defines required attributes with coercion" do
      klass = Class.new(described_class) do
        required :count, type: :integer

        def work
          context.doubled = count * 2
        end
      end

      result = klass.execute(count: "5")
      expect(result).to be_success
      expect(result.context.doubled).to eq(10)
    end

    it "fails on missing required attributes" do
      klass = Class.new(described_class) do
        required :name
      end

      result = klass.execute
      expect(result).to be_failed
      expect(result.reason).to eq("Invalid")
    end

    it "allows optional attributes to be nil" do
      klass = Class.new(described_class) do
        optional :note

        def work
          context.has_note = !note.nil?
        end
      end

      result = klass.execute
      expect(result).to be_success
      expect(result.context.has_note).to be(false)
    end

    it "applies defaults" do
      klass = Class.new(described_class) do
        optional :role, default: "member"

        def work
          context.used_role = role
        end
      end

      result = klass.execute
      expect(result.context.used_role).to eq("member")
    end

    it "validates attributes" do
      klass = Class.new(described_class) do
        required :email, presence: true
      end

      result = klass.execute(email: "")
      expect(result).to be_failed
    end

    it "applies transformations" do
      klass = Class.new(described_class) do
        required :tag, transform: ->(v) { v.to_s.downcase.strip }

        def work
          context.clean_tag = tag
        end
      end

      result = klass.execute(tag: "  HELLO  ")
      expect(result.context.clean_tag).to eq("hello")
    end
  end

  describe "halt methods" do
    it "skip! sets result to skipped" do
      klass = Class.new(described_class) do
        def work
          skip!("done already")
        end
      end

      result = klass.execute
      expect(result).to be_skipped
      expect(result.reason).to eq("done already")
    end

    it "fail! sets result to failed with metadata" do
      klass = Class.new(described_class) do
        def work
          fail!("bad input", code: 422)
        end
      end

      result = klass.execute
      expect(result).to be_failed
      expect(result.metadata[:code]).to eq(422)
    end

    it "success! annotates success" do
      klass = Class.new(described_class) do
        def work
          success!("imported 42 records", count: 42)
        end
      end

      result = klass.execute
      expect(result).to be_success
      expect(result.reason).to eq("imported 42 records")
      expect(result.metadata[:count]).to eq(42)
    end
  end

  describe "exception handling" do
    it "captures exceptions as failed results" do
      klass = Class.new(described_class) do
        def work
          raise StandardError, "boom"
        end
      end

      result = klass.execute
      expect(result).to be_failed
      expect(result.reason).to include("boom")
    end
  end

  describe "dry_run?" do
    it "detects dry run mode" do
      klass = Class.new(described_class) do
        def work
          context.mode = dry_run? ? "dry" : "live"
        end
      end

      result = klass.execute(dry_run: true)
      expect(result.context.mode).to eq("dry")
      expect(result).to be_dry_run
    end
  end

  describe "rollback" do
    it "calls rollback on failure" do
      klass = Class.new(described_class) do
        def work
          fail!("bad")
        end

        def rollback
          context.rolled_back = true
        end
      end

      result = klass.execute
      expect(result).to be_rolled_back
      expect(result.context.rolled_back).to be(true)
    end
  end

  describe "retries" do
    it "retries on configured exceptions" do
      attempts = 0
      klass = Class.new(described_class) do
        settings(retries: 2, retry_on: [RuntimeError])

        define_method(:work) do
          attempts += 1
          raise RuntimeError, "fail" if attempts < 3

          context.done = true
        end
      end

      result = klass.execute
      expect(result).to be_success
      expect(result).to be_retried
      expect(result.retries).to eq(2)
    end
  end

  describe "single-use" do
    it "raises on double execution" do
      klass = Class.new(described_class) do
        def work; end
      end

      task = klass.new
      task.execute
      expect { task.execute }.to raise_error(RuntimeError, /already been executed/)
    end
  end

  describe "inheritance" do
    it "inherits attributes from parent" do
      parent = Class.new(described_class) do
        required :base_id
      end

      child = Class.new(parent) do
        required :child_name

        def work
          context.ids = "#{base_id}-#{child_name}"
        end
      end

      result = child.execute(base_id: "A", child_name: "B")
      expect(result).to be_success
      expect(result.context.ids).to eq("A-B")
    end
  end

  describe "returns" do
    it "passes when returns are set" do
      klass = Class.new(described_class) do
        returns :token

        def work
          context.token = "abc"
        end
      end

      expect(klass.execute).to be_success
    end

    it "fails when returns are missing" do
      klass = Class.new(described_class) do
        returns :token

        def work; end
      end

      result = klass.execute
      expect(result).to be_failed
      expect(result.metadata[:errors][:messages]).to have_key(:token)
    end
  end

  describe "callbacks" do
    it "runs before_execution and on_success" do
      klass = Class.new(described_class) do
        before_execution :setup
        on_success :mark_done

        def work
          context.worked = true
        end

        private

        def setup
          context.setup = true
        end

        def mark_done
          context.done = true
        end
      end

      result = klass.execute
      expect(result.context.setup).to be(true)
      expect(result.context.worked).to be(true)
      expect(result.context.done).to be(true)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Task middlewares", type: :feature do
  describe "execution wrapping" do
    it "wraps #work with before and after hooks" do
      log = []
      task = create_successful_task do
        register :middleware, proc { |_task, &nxt|
          log << :before
          nxt.call
          log << :after
        }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(log).to eq(%i[before after])
    end

    it "nests multiple middlewares in registration order" do
      log = []
      task = create_successful_task do
        register :middleware, proc { |_task, &nxt|
          log << :outer_in
          nxt.call
          log << :outer_out
        }
        register :middleware, proc { |_task, &nxt|
          log << :inner_in
          nxt.call
          log << :inner_out
        }
      end

      task.execute

      expect(log).to eq(%i[outer_in inner_in inner_out outer_out])
    end

    it "still runs callbacks and #work inside the middleware chain" do
      log = []
      task = create_successful_task do
        register :middleware, proc { |_task, &nxt|
          log << :mw_in
          nxt.call
          log << :mw_out
        }
        before_execution { log << :before_execution }
        on_success { log << :on_success }
      end

      task.execute

      expect(log).to eq(%i[mw_in before_execution on_success mw_out])
    end
  end

  describe "registration forms" do
    it "accepts a block" do
      log = []
      task = create_successful_task do
        register(:middleware) do |_task, &nxt|
          log << :block_in
          nxt.call
          log << :block_out
        end
      end

      task.execute

      expect(log).to eq(%i[block_in block_out])
    end

    it "accepts a callable object with #call" do
      mw_class = Class.new do
        def call(task)
          task.context.touched = true
          yield
        end
      end

      task = create_successful_task do
        register :middleware, mw_class.new
      end

      expect(task.execute.context[:touched]).to be(true)
    end

    it "rejects non-callable middlewares" do
      expect do
        create_task_class(name: "BadMiddleware") { register :middleware, "nope" }
      end.to raise_error(ArgumentError, /middleware must respond to #call/)
    end

    it "rejects both a callable and a block" do
      expect do
        create_task_class(name: "BothMiddleware") do
          register(:middleware, proc {}) { nil }
        end
      end.to raise_error(ArgumentError, /either a callable or a block, not both/)
    end
  end

  describe "misbehavior" do
    it "raises MiddlewareError when the middleware never yields" do
      task = create_successful_task do
        register :middleware, proc { |_task| }
      end

      expect { task.execute }.to raise_error(CMDx::MiddlewareError, /did not yield to next_link/)
    end
  end

  describe "inheritance" do
    it "inherits parent middlewares and preserves nesting order" do
      log = []
      parent = create_successful_task(name: "Parent") do
        register :middleware, proc { |_task, &nxt|
          log << :parent_in
          nxt.call
          log << :parent_out
        }
      end

      child = create_successful_task(base: parent, name: "Child") do
        register :middleware, proc { |_task, &nxt|
          log << :child_in
          nxt.call
          log << :child_out
        }
      end

      child.execute

      expect(log).to eq(%i[parent_in child_in child_out parent_out])
    end
  end

  describe "positional insertion" do
    it "inserts a middleware at the given index" do
      log = []
      make = lambda do |label|
        proc do |_task, &nxt|
          log << :"#{label}_in"
          nxt.call
          log << :"#{label}_out"
        end
      end

      task = create_successful_task do
        register :middleware, make.call(:outer)
        register :middleware, make.call(:inner)
        register :middleware, make.call(:middle), at: 1
      end

      task.execute

      expect(log).to eq(%i[outer_in middle_in inner_in inner_out middle_out outer_out])
    end
  end

  describe "deregister" do
    it "removes a middleware by reference" do
      log = []
      mw = proc do |_task, &nxt|
        log << :removed_mw
        nxt.call
      end
      task = create_successful_task do
        register :middleware, mw
        deregister :middleware, mw
      end

      task.execute

      expect(log).to be_empty
    end
  end

  describe "metadata enrichment" do
    let(:request_id_middleware) do
      Class.new do
        def call(task)
          task.metadata[:request_id] = "req-abc123"
          yield
        end
      end.new
    end

    it "propagates middleware-injected metadata on implicit success" do
      task = create_successful_task do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
      end

      result = task.execute

      expect(result).to have_attributes(
        status: CMDx::Signal::SUCCESS,
        metadata: { request_id: "req-abc123" }
      )
    end

    it "propagates middleware-injected metadata on explicit success!" do
      task = create_task_class do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
        define_method(:work) { success!("ok", code: 200) }
      end

      expect(task.execute.metadata).to eq(request_id: "req-abc123", code: 200)
    end

    it "propagates middleware-injected metadata on skip!" do
      task = create_skipping_task(reason: "later") do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
      end

      expect(task.execute).to have_attributes(
        status: CMDx::Signal::SKIPPED,
        metadata: { request_id: "req-abc123" }
      )
    end

    it "propagates middleware-injected metadata on fail!" do
      task = create_failing_task(reason: "boom", code: "E001") do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
      end

      expect(task.execute.metadata).to eq(request_id: "req-abc123", code: "E001")
    end

    it "propagates middleware-injected metadata when an unrescued exception fails the task" do
      task = create_erroring_task(reason: "boom") do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
      end

      expect(task.execute).to have_attributes(
        status: CMDx::Signal::FAILED,
        metadata: { request_id: "req-abc123" }
      )
    end

    it "propagates middleware-injected metadata when input validation fails" do
      task = create_task_class do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
        input :name, type: :string, required: true
        define_method(:work) { :unreachable }
      end

      expect(task.execute).to have_attributes(
        status: CMDx::Signal::FAILED,
        metadata: { request_id: "req-abc123" }
      )
    end

    it "lets explicit signal kwargs override middleware-set keys" do
      task = create_task_class do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "from-mw"
          nxt.call
        }
        define_method(:work) { fail!("boom", request_id: "from-work") }
      end

      expect(task.execute.metadata[:request_id]).to eq("from-work")
    end

    it "supports a class-based middleware mutating task.metadata" do
      mw = request_id_middleware
      task = create_successful_task { register :middleware, mw }

      expect(task.execute.metadata).to eq(request_id: "req-abc123")
    end

    it "preserves the Signal.success singleton when no middleware mutates metadata" do
      task = create_successful_task

      expect(task.execute.metadata).to be_empty
    end

    it "stacks contributions from multiple middlewares" do
      task = create_successful_task do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
        register :middleware, proc { |t, &nxt|
          t.metadata[:tenant_id] = 42
          nxt.call
        }
      end

      expect(task.execute.metadata).to eq(request_id: "req-abc123", tenant_id: 42)
    end

    it "carries metadata into echoed signals from re-thrown peer faults" do
      inner = create_failing_task(reason: "inner boom", inner_key: :v)
      task = create_task_class do
        register :middleware, proc { |t, &nxt|
          t.metadata[:request_id] = "req-abc123"
          nxt.call
        }
        define_method(:work) { throw!(inner.execute(context)) }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "inner boom")
      expect(result.metadata[:request_id]).to eq("req-abc123")
    end
  end
end

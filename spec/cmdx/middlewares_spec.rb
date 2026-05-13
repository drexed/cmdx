# frozen_string_literal: true

RSpec.describe CMDx::Middlewares do
  subject(:middlewares) { described_class.new }

  let(:task) { Object.new }

  describe "#initialize" do
    it "starts with an empty registry" do
      expect(middlewares).to be_empty
      expect(middlewares.registry).to eq([])
    end
  end

  describe "#initialize_copy" do
    it "dups the registry so new registrations don't leak" do
      mw = ->(_t, &blk) { blk.call }
      middlewares.register(mw)

      copy = middlewares.dup
      copy.register(->(_t, &blk) { blk.call })

      expect(middlewares.size).to eq(1)
      expect(copy.size).to eq(2)
    end
  end

  describe "#register" do
    let(:mw) { ->(_t, &blk) { blk.call } }

    it "appends the callable and returns self" do
      expect(middlewares.register(mw)).to be(middlewares)
      expect(middlewares.registry).to eq([[mw, {}]])
    end

    it "accepts a block" do
      middlewares.register { |_t, &blk| blk.call }
      expect(middlewares.size).to eq(1)
    end

    it "stores :if/:unless options on the entry" do
      gate = -> { true }
      middlewares.register(mw, if: :run?, unless: gate)
      _, opts = middlewares.registry.first
      expect(opts).to eq(if: :run?, unless: gate)
      expect(opts).to be_frozen
    end

    it "raises when both callable and block are given" do
      expect { middlewares.register(mw) { |_t, &blk| blk.call } }
        .to raise_error(ArgumentError, /middleware: provide either a callable or a block, not both/)
    end

    it "raises when the middleware does not respond to #call" do
      expect { middlewares.register("not callable") }
        .to raise_error(ArgumentError, /middleware must respond to #call/)
    end

    it "raises when at is non-integer" do
      expect { middlewares.register(mw, at: "1") }
        .to raise_error(ArgumentError, /middleware :at must be an Integer/)
    end

    it "inserts at the given positive index" do
      a = ->(_t, &blk) { blk.call }
      b = ->(_t, &blk) { blk.call }
      c = ->(_t, &blk) { blk.call }

      middlewares.register(a)
      middlewares.register(b)
      middlewares.register(c, at: 1)

      expect(middlewares.registry.map(&:first)).to eq([a, c, b])
    end

    it "clamps out-of-bounds indices to the valid range" do
      a = ->(_t, &blk) { blk.call }
      b = ->(_t, &blk) { blk.call }
      c = ->(_t, &blk) { blk.call }

      middlewares.register(a)
      middlewares.register(b, at: 100)
      middlewares.register(c, at: -100)

      expect(middlewares.registry.first.first).to be(c)
      expect(middlewares.registry.last.first).to be(b)
    end
  end

  describe "#deregister" do
    let(:mw) { ->(_t, &blk) { blk.call } }

    before { middlewares.register(mw) }

    it "removes a specific middleware and returns self" do
      expect(middlewares.deregister(mw)).to be(middlewares)
      expect(middlewares).to be_empty
    end

    it "removes by index" do
      middlewares.deregister(at: 0)
      expect(middlewares).to be_empty
    end

    it "raises when neither a middleware nor an index is provided" do
      expect { middlewares.deregister }
        .to raise_error(ArgumentError, /middleware: provide either a middleware or an at: index/)
    end

    it "raises when both a middleware and an index are provided" do
      expect { middlewares.deregister(mw, at: 0) }
        .to raise_error(ArgumentError, /middleware: provide either a middleware or an at: index, not both/)
    end

    it "raises when at is non-integer" do
      expect { middlewares.deregister(at: "1") }
        .to raise_error(ArgumentError, /middleware :at must be an Integer/)
    end
  end

  describe "#process" do
    it "yields once when there are no middlewares" do
      yields = 0
      middlewares.process(task) { yields += 1 }
      expect(yields).to eq(1)
    end

    it "runs each middleware in registration order around the inner block" do
      trace = []
      middlewares.register(lambda { |_t, &blk|
        trace << :a_before
        blk.call
        trace << :a_after
      })
      middlewares.register(lambda { |_t, &blk|
        trace << :b_before
        blk.call
        trace << :b_after
      })

      middlewares.process(task) { trace << :inner }

      expect(trace).to eq(%i[a_before b_before inner b_after a_after])
    end

    it "passes the task to each middleware" do
      seen = []
      middlewares.register(lambda do |t, &blk|
        seen << t
        blk.call
      end)

      middlewares.process(task) { :ok }
      expect(seen).to eq([task])
    end

    it "invokes the inner block through the chain" do
      middlewares.register(->(_t, &blk) { blk.call })

      called = false
      middlewares.process(task) { called = true }
      expect(called).to be(true)
    end

    it "raises MiddlewareError when a middleware fails to yield" do
      middlewares.register(->(_t, &_blk) { :no_yield })

      expect { middlewares.process(task) { :inner } }
        .to raise_error(CMDx::MiddlewareError, /did not yield to next_link/)
    end

    context "with :if/:unless gates" do
      let(:task) { Struct.new(:enabled).new(false) }

      it "skips middleware whose :if gate is falsy" do
        trace = []
        mw = lambda { |_t, &blk|
          trace << :ran
          blk.call
        }
        middlewares.register(mw, if: :enabled)

        middlewares.process(task) { trace << :inner }

        expect(trace).to eq([:inner])
      end

      it "runs middleware whose :unless gate is falsy" do
        task.enabled = true
        trace = []
        mw = lambda { |_t, &blk|
          trace << :ran
          blk.call
        }
        middlewares.register(mw, unless: proc { !enabled })

        middlewares.process(task) { trace << :inner }

        expect(trace).to eq(%i[ran inner])
      end

      it "still walks subsequent middlewares when an earlier one is gated out" do
        trace = []
        middlewares.register(lambda { |_t, &blk|
          trace << :a
          blk.call
        }, if: proc { false })
        middlewares.register(lambda { |_t, &blk|
          trace << :b
          blk.call
        })

        middlewares.process(task) { trace << :inner }

        expect(trace).to eq(%i[b inner])
      end
    end
  end

  describe "#size / #empty?" do
    it "tracks registry state" do
      expect(middlewares).to be_empty
      expect(middlewares.size).to eq(0)

      middlewares.register(->(_t, &blk) { blk.call })

      expect(middlewares).not_to be_empty
      expect(middlewares.size).to eq(1)
    end
  end
end

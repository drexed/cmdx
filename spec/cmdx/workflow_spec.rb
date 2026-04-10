# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow do
  describe "DSL and execution" do
    let(:order) { [] }

    let(:step_one) do
      o = order
      Class.new(CMDx::Task) do
        define_method(:work) { o << :one }
      end
    end

    let(:step_two) do
      o = order
      Class.new(CMDx::Task) do
        define_method(:work) { o << :two }
      end
    end

    let(:strict_fail) do
      Class.new(CMDx::Task) do
        def work
          fail!("halt", halt: true, strict: true)
        end
      end
    end

    let(:soft_fail) do
      Class.new(CMDx::Task) do
        def work
          fail!("soft", halt: true, strict: false)
        end
      end
    end

    it ".task declares sequential steps and runs in order" do
      s1 = step_one
      s2 = step_two
      wf = Class.new(CMDx::Task) do
        include CMDx::Workflow

        task s1
        task s2
      end
      wf.execute
      expect(order).to eq(%i[one two])
    end

    it ".tasks declares parallel steps that all run" do
      seen = []
      a = Class.new(CMDx::Task) { define_method(:work) { seen << :a } }
      b = Class.new(CMDx::Task) { define_method(:work) { seen << :b } }
      wf = Class.new(CMDx::Task) do
        include CMDx::Workflow

        tasks a, b, pool_size: 2
      end
      wf.execute
      expect(seen.sort).to eq(%i[a b])
    end

    it "halts on strict failure" do
      s1 = step_one
      s2 = step_two
      sf = strict_fail
      wf = Class.new(CMDx::Task) do
        include CMDx::Workflow

        task s1
        task sf
        task s2
      end
      wf.execute
      expect(order).to eq([:one])
    end

    it "continues when failure is not strict" do
      s1 = step_one
      s2 = step_two
      sf = soft_fail
      wf = Class.new(CMDx::Task) do
        include CMDx::Workflow

        task s1
        task sf
        task s2
      end
      wf.execute
      expect(order).to eq(%i[one two])
    end

    it "does not halt the pipeline when on_failure is :skip (even if the step fails strict)" do
      s1 = step_one
      s2 = step_two
      sf = strict_fail
      wf = Class.new(CMDx::Task) do
        include CMDx::Workflow

        task s1
        task sf, on_failure: :skip
        task s2
      end
      r = wf.execute
      expect(r.success?).to be(true)
      expect(order).to eq(%i[one two])
    end
  end
end

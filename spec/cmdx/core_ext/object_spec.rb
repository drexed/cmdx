# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoreExt::ObjectExtensions do # rubocop:disable RSpec/SpecFilePathFormat
  let(:test_object) { Object.new }
  let(:test_hash) { { name: "John", age: 30 } }
  let(:test_proc) { -> { "proc_result" } }
  let(:test_lambda) { ->(x) { x * 2 } }

  describe "#cmdx_try" do
    context "with method calls" do
      it "calls existing methods" do
        expect("hello".cmdx_try(:upcase)).to eq("HELLO")
        expect("hello".cmdx_try(:length)).to eq(5)
      end

      it "calls methods with arguments" do
        expect("hello".cmdx_try(:[], 1)).to eq("e")
        expect([1, 2, 3].cmdx_try(:join, "-")).to eq("1-2-3")
      end

      it "calls private methods when they exist" do
        expect(test_object.cmdx_try(:object_id)).to be_a(Integer)
      end

      it "returns nil for non-existent methods" do
        expect("hello".cmdx_try(:missing_method)).to be_nil
        expect(test_object.cmdx_try(:undefined)).to be_nil
      end
    end

    context "with hash access" do
      it "accesses hash keys" do
        expect(test_hash.cmdx_try(:name)).to eq("John")
        expect(test_hash.cmdx_try(:age)).to eq(30)
      end

      it "returns nil for missing hash keys" do
        expect(test_hash.cmdx_try(:missing)).to be_nil
      end
    end

    context "with edge cases" do
      it "handles nil gracefully" do
        expect { test_object.cmdx_try(nil) }.to raise_error(TypeError)
      end

      it "handles empty arguments" do
        expect("hello".cmdx_try(:upcase)).to eq("HELLO")
      end
    end
  end

  describe "#cmdx_eval" do
    let(:active_user) { double("User", active?: true, banned?: false) }
    let(:inactive_user) { double("User", active?: false, banned?: false) }
    let(:banned_user) { double("User", active?: true, banned?: true) }

    context "with :if condition" do
      it "returns true when condition is truthy" do
        expect(active_user.cmdx_eval(if: :active?)).to be true
      end

      it "returns false when condition is falsy" do
        expect(inactive_user.cmdx_eval(if: :active?)).to be false
      end
    end

    context "with :unless condition" do
      it "returns true when condition is falsy" do
        expect(active_user.cmdx_eval(unless: :banned?)).to be true
      end

      it "returns false when condition is truthy" do
        expect(banned_user.cmdx_eval(unless: :banned?)).to be false
      end
    end

    context "with both :if and :unless conditions" do
      it "returns true when both conditions are met" do
        expect(active_user.cmdx_eval(if: :active?, unless: :banned?)).to be true
      end

      it "returns false when :if condition fails" do
        expect(inactive_user.cmdx_eval(if: :active?, unless: :banned?)).to be false
      end

      it "returns false when :unless condition fails" do
        expect(banned_user.cmdx_eval(if: :active?, unless: :banned?)).to be false
      end
    end

    context "with no conditions" do
      it "returns default value (true)" do
        expect(test_object.cmdx_eval).to be true
      end

      it "returns custom default value" do
        expect(test_object.cmdx_eval(default: false)).to be false
        expect(test_object.cmdx_eval(default: "custom")).to eq("custom")
      end
    end

    context "with edge cases" do
      it "handles nil conditions" do
        expect(test_object.cmdx_eval(if: nil)).to be true
        expect(test_object.cmdx_eval(unless: nil)).to be true
      end

      it "handles non-existent methods" do
        expect(test_object.cmdx_eval(if: :missing_method)).to be_falsy
        expect(test_object.cmdx_eval(unless: :missing_method)).to be true
      end
    end
  end

  describe "#cmdx_yield" do
    let(:yielding_object) { double("Object", custom_method: "method_result") }

    context "with symbol/string method names" do
      it "calls methods for symbols" do
        expect("hello".cmdx_yield(:upcase)).to eq("HELLO")
        expect(yielding_object.cmdx_yield(:custom_method)).to eq("method_result")
      end

      it "calls methods for strings" do
        expect("hello".cmdx_yield("upcase")).to eq("HELLO")
        expect(yielding_object.cmdx_yield("custom_method")).to eq("method_result")
      end

      it "returns symbol/string as-is when method doesn't exist" do
        expect(test_object.cmdx_yield(:missing_method)).to eq(:missing_method)
        expect(test_object.cmdx_yield("missing_method")).to eq("missing_method")
      end

      it "calls methods with arguments" do
        expect("hello".cmdx_yield(:[], 1)).to eq("e")
        expect([1, 2, 3].cmdx_yield(:join, "-")).to eq("1-2-3")
      end
    end

    context "with hash objects" do
      it "returns key as-is when hash doesn't have method" do
        expect(test_hash.cmdx_yield(:name)).to eq(:name)
        expect(test_hash.cmdx_yield(:age)).to eq(:age)
      end

      it "returns symbol as-is for missing keys" do
        expect(test_hash.cmdx_yield(:missing)).to eq(:missing)
      end
    end

    context "with proc objects" do
      it "evaluates procs using cmdx_try" do
        expect(test_object.cmdx_yield(test_proc)).to eq("proc_result")
        expect(test_object.cmdx_yield(test_lambda, 3)).to eq(6)
      end
    end

    context "with other objects" do
      it "returns the object as-is" do
        expect(test_object.cmdx_yield(42)).to eq(42)
        expect(test_object.cmdx_yield("static")).to eq("static")
        expect(test_object.cmdx_yield(nil)).to be_nil
        expect(test_object.cmdx_yield([])).to eq([])
      end
    end
  end

  describe "#cmdx_call" do
    let(:callable_object) { double("Callable", call: "called") }
    let(:proc_object) { -> { "proc_called" } }
    let(:lambda_object) { ->(x) { "lambda_#{x}" } }

    context "with callable objects" do
      it "calls objects that respond to call" do
        expect(callable_object.cmdx_call).to eq("called")
        expect(proc_object.cmdx_call).to eq("proc_called")
        expect(lambda_object.cmdx_call("test")).to eq("lambda_test")
      end

      it "passes arguments to callable objects" do
        callable_with_args = double("Callable")
        expect(callable_with_args).to receive(:call).with("arg1", "arg2").and_return("result")
        expect(callable_with_args.cmdx_call("arg1", "arg2")).to eq("result")
      end
    end

    context "with non-callable objects" do
      it "returns the object itself" do
        expect(test_object.cmdx_call).to eq(test_object)
        expect("string".cmdx_call).to eq("string")
        expect(42.cmdx_call).to eq(42)
        expect([1, 2, 3].cmdx_call).to eq([1, 2, 3])
      end
    end
  end

  describe "integration" do
    context "with complex scenarios" do
      let(:complex_object) do
        Class.new do
          def initialize(active = true)
            @active = active
          end

          def active?
            @active
          end

          def status
            @active ? "active" : "inactive"
          end

          def call
            "called"
          end
        end.new
      end

      it "works with method chains" do
        expect(complex_object.cmdx_try(:status)).to eq("active")
        expect(complex_object.cmdx_eval(if: :active?)).to be true
        expect(complex_object.cmdx_yield(:status)).to eq("active")
        expect(complex_object.cmdx_call).to eq("called")
      end

      it "handles conditional evaluation with try" do
        inactive_object = complex_object.class.new(false)
        expect(inactive_object.cmdx_try(:status)).to eq("inactive")
        expect(inactive_object.cmdx_eval(if: :active?)).to be false
        expect(inactive_object.cmdx_eval(unless: :active?)).to be true
      end
    end
  end
end

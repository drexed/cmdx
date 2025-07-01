# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Correlate do
  subject(:middleware) { described_class.new(options) }

  let(:options) { {} }
  let(:task) { double("task", chain: chain, __cmdx_eval: true, __cmdx_yield: nil) }
  let(:chain) { double("chain", id: "chain-123") }
  let(:callable) { double("callable") }
  let(:result) { double("result") }

  before do
    allow(callable).to receive(:call).with(task).and_return(result)
    allow(CMDx::Correlator).to receive_messages(id: nil, generate: "generated-uuid")
    allow(CMDx::Correlator).to receive(:use).and_yield
  end

  describe "#initialize" do
    context "with no options" do
      it "sets id to nil" do
        expect(middleware.id).to be_nil
      end

      it "sets conditional to empty hash" do
        expect(middleware.conditional).to eq({})
      end
    end

    context "with id option" do
      let(:options) { { id: "custom-id" } }

      it "sets id to provided value" do
        expect(middleware.id).to eq("custom-id")
      end
    end

    context "with conditional options" do
      let(:options) { { if: :enabled?, unless: :disabled? } }

      it "extracts conditional options" do
        expect(middleware.conditional).to eq({ if: :enabled?, unless: :disabled? })
      end
    end

    context "with mixed options" do
      let(:options) { { id: "test-id", if: :active?, other: "ignored" } }

      it "sets id correctly" do
        expect(middleware.id).to eq("test-id")
      end

      it "extracts only conditional options" do
        expect(middleware.conditional).to eq({ if: :active? })
      end
    end
  end

  describe "#call" do
    context "when conditions are not met" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(false)
      end

      it "calls the callable without correlation setup" do
        result = middleware.call(task, callable)

        expect(callable).to have_received(:call).with(task)
        expect(CMDx::Correlator).not_to have_received(:use)
        expect(result).to eq(result)
      end
    end

    context "when conditions are met" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
      end

      context "with explicit correlation id" do
        let(:options) { { id: "explicit-id" } }

        before do
          allow(task).to receive(:__cmdx_yield).with("explicit-id").and_return("explicit-id")
        end

        it "uses explicit correlation id" do
          middleware.call(task, callable)

          expect(CMDx::Correlator).to have_received(:use).with("explicit-id")
        end

        it "calls the callable within correlation context" do
          middleware.call(task, callable)

          expect(callable).to have_received(:call).with(task)
        end

        it "returns the callable result" do
          result = middleware.call(task, callable)

          expect(result).to eq(result)
        end
      end

      context "with proc-based correlation id" do
        let(:options) { { id: proc { "proc-id" } } }

        before do
          allow(task).to receive(:__cmdx_yield).with(options[:id]).and_return("proc-result")
        end

        it "uses result from proc execution" do
          middleware.call(task, callable)

          expect(CMDx::Correlator).to have_received(:use).with("proc-result")
        end
      end

      context "with method-based correlation id" do
        let(:options) { { id: :correlation_method } }

        before do
          allow(task).to receive(:__cmdx_yield).with(:correlation_method).and_return("method-result")
        end

        it "uses result from method call" do
          middleware.call(task, callable)

          expect(CMDx::Correlator).to have_received(:use).with("method-result")
        end
      end

      context "when id yields nil" do
        let(:options) { { id: "test-id" } }

        before do
          allow(task).to receive(:__cmdx_yield).with("test-id").and_return(nil)
        end

        context "with existing thread correlation" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return("thread-correlation")
          end

          it "uses thread correlation id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("thread-correlation")
          end
        end

        context "without thread correlation but with chain id" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return(nil)
            allow(chain).to receive(:id).and_return("chain-456")
          end

          it "uses chain id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("chain-456")
          end
        end

        context "without thread correlation or chain id" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return(nil)
            allow(chain).to receive(:id).and_return(nil)
          end

          it "uses generated correlation id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("generated-uuid")
          end

          it "generates new correlation id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:generate)
          end
        end
      end

      context "without explicit id" do
        context "with existing thread correlation" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return("current-thread-id")
          end

          it "uses current thread correlation" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("current-thread-id")
          end
        end

        context "without thread correlation" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return(nil)
          end

          it "uses chain id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("chain-123")
          end
        end

        context "without thread correlation and nil chain id" do
          before do
            allow(CMDx::Correlator).to receive(:id).and_return(nil)
            allow(chain).to receive(:id).and_return(nil)
          end

          it "uses generated correlation id" do
            middleware.call(task, callable)

            expect(CMDx::Correlator).to have_received(:use).with("generated-uuid")
          end
        end
      end

      context "with conditional execution" do
        let(:options) { { if: :enabled?, unless: :disabled? } }

        before do
          allow(task).to receive(:__cmdx_eval).with({ if: :enabled?, unless: :disabled? }).and_return(true)
        end

        it "evaluates conditions before applying correlation" do
          middleware.call(task, callable)

          expect(task).to have_received(:__cmdx_eval).with({ if: :enabled?, unless: :disabled? })
          expect(CMDx::Correlator).to have_received(:use)
        end
      end

      context "when callable raises exception" do
        let(:error) { StandardError.new("test error") }

        before do
          allow(callable).to receive(:call).and_raise(error)
          allow(CMDx::Correlator).to receive(:use).and_call_original
        end

        it "allows exception to propagate" do
          expect { middleware.call(task, callable) }.to raise_error(StandardError, "test error")
        end
      end
    end

    context "with complex correlation precedence" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
      end

      it "follows correct precedence order" do
        # Test that explicit id takes precedence over thread correlation
        allow(task).to receive(:__cmdx_yield).with("explicit").and_return("explicit-result")
        allow(CMDx::Correlator).to receive(:id).and_return("thread-id")

        middleware_with_id = described_class.new(id: "explicit")
        middleware_with_id.call(task, callable)

        expect(CMDx::Correlator).to have_received(:use).with("explicit-result")
      end

      it "uses thread correlation when explicit yields nil" do
        allow(task).to receive(:__cmdx_yield).with("explicit").and_return(nil)
        allow(CMDx::Correlator).to receive(:id).and_return("thread-id")

        middleware_with_id = described_class.new(id: "explicit")
        middleware_with_id.call(task, callable)

        expect(CMDx::Correlator).to have_received(:use).with("thread-id")
      end

      it "uses chain id when both explicit and thread are nil" do
        allow(task).to receive(:__cmdx_yield).with("explicit").and_return(nil)
        allow(CMDx::Correlator).to receive(:id).and_return(nil)
        allow(chain).to receive(:id).and_return("chain-id")

        middleware_with_id = described_class.new(id: "explicit")
        middleware_with_id.call(task, callable)

        expect(CMDx::Correlator).to have_received(:use).with("chain-id")
      end

      it "generates new id when all sources are nil" do
        allow(task).to receive(:__cmdx_yield).with("explicit").and_return(nil)
        allow(CMDx::Correlator).to receive(:id).and_return(nil)
        allow(chain).to receive(:id).and_return(nil)

        middleware_with_id = described_class.new(id: "explicit")
        middleware_with_id.call(task, callable)

        expect(CMDx::Correlator).to have_received(:use).with("generated-uuid")
      end
    end
  end

  describe "inheritance" do
    it "inherits from CMDx::Middleware" do
      expect(described_class).to be < CMDx::Middleware
    end
  end

  describe "attribute readers" do
    let(:options) { { id: "test-id", if: :condition } }

    it "provides access to id" do
      expect(middleware.id).to eq("test-id")
    end

    it "provides access to conditional options" do
      expect(middleware.conditional).to eq({ if: :condition })
    end
  end
end

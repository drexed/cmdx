# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  subject(:validator) { described_class.call(value, options) }

  let(:value) { "abc12" }
  let(:options) do
    { length: {} }
  end

  describe ".call" do
    context "with unmatched options" do
      let(:options) do
        { length: { between: 1..5 } }
      end

      it "raises an ArgumentError" do
        expect { validator }.to raise_error(ArgumentError, "no known length validator options given")
      end
    end

    context "with min option" do
      let(:options) do
        { length: { min: 1 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:value) { "" }

        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must be at least 1")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { min: 1, message: "custom message %{min}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1")
          end
        end
      end
    end

    context "with max option" do
      let(:options) do
        { length: { max: 5 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:value) { "abc123" }

        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must be at most 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { max: 5, message: "custom message %{max}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
          end
        end
      end
    end

    context "with min and max option" do
      let(:options) do
        { length: { min: 1, max: 5 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:value) { "abc123" }

        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must be within 1 and 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { min: 1, max: 5, message: "custom message %{min} and %{max}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
          end
        end
      end
    end

    context "with within option" do
      let(:options) do
        { length: { within: (1..5) } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:value) { "abc123" }

        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must be within 1 and 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { within: (1..5), message: "custom message %{min} and %{max}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
          end
        end
      end
    end

    context "with not within option" do
      let(:options) do
        { length: { not_within: (1..5) } }
      end

      context "when valid" do
        let(:value) { "abc123" }

        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must not be within 1 and 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { not_within: (1..5), message: "custom message %{min} and %{max}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 1 and 5")
          end
        end
      end
    end

    context "with is option" do
      let(:options) do
        { length: { is: 5 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:value) { "abc123" }

        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must be 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { is: 5, message: "custom message %{is}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
          end
        end
      end
    end

    context "with is not option" do
      let(:options) do
        { length: { is_not: 5 } }
      end

      context "when valid" do
        let(:value) { "abc123" }

        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        context "with default message" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "length must not be 5")
          end
        end

        context "with custom message" do
          let(:options) do
            { length: { is_not: 5, message: "custom message %{is_not}" } }
          end

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "custom message 5")
          end
        end
      end
    end
  end
end

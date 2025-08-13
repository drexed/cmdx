# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion, type: :unit do
  subject(:validator) { described_class }

  describe ".call" do
    context "with array exclusions" do
      context "when using :in option" do
        let(:options) { { in: %w[admin root system] } }

        context "when value is excluded" do
          it "raises ValidationError with default message" do
            expect { validator.call("admin", options) }
              .to raise_error(CMDx::ValidationError, 'must not be one of: "admin", "root", "system"')
          end

          it "raises ValidationError for any excluded value" do
            %w[admin root system].each do |excluded_value|
              expect { validator.call(excluded_value, options) }
                .to raise_error(CMDx::ValidationError, 'must not be one of: "admin", "root", "system"')
            end
          end
        end

        context "when value is not excluded" do
          it "does not raise error for allowed values" do
            expect { validator.call("user", options) }.not_to raise_error
            expect { validator.call("guest", options) }.not_to raise_error
            expect { validator.call("", options) }.not_to raise_error
          end
        end

        context "with custom :of_message" do
          let(:options) { { in: %w[reserved blocked], of_message: "is a reserved username" } }

          it "uses custom message" do
            expect { validator.call("reserved", options) }
              .to raise_error(CMDx::ValidationError, "is a reserved username")
          end
        end

        context "with custom :message" do
          let(:options) { { in: %w[forbidden], message: "cannot be used" } }

          it "uses custom message" do
            expect { validator.call("forbidden", options) }
              .to raise_error(CMDx::ValidationError, "cannot be used")
          end
        end

        context "with message interpolation" do
          let(:options) { { in: %w[bad evil], of_message: "value %<values>s not allowed" } }

          it "interpolates values into custom message" do
            expect { validator.call("bad", options) }
              .to raise_error(CMDx::ValidationError, 'value "bad", "evil" not allowed')
          end
        end
      end

      context "when using :within option" do
        let(:options) { { within: %w[admin root] } }

        context "when value is excluded" do
          it "raises ValidationError with default message" do
            expect { validator.call("admin", options) }
              .to raise_error(CMDx::ValidationError, 'must not be one of: "admin", "root"')
          end
        end

        context "when value is not excluded" do
          it "does not raise error" do
            expect { validator.call("user", options) }.not_to raise_error
          end
        end
      end

      context "with different data types" do
        context "with integers" do
          let(:options) { { in: [1, 2, 3] } }

          it "excludes integer values" do
            expect { validator.call(2, options) }
              .to raise_error(CMDx::ValidationError, "must not be one of: 1, 2, 3")
          end

          it "allows non-excluded integers" do
            expect { validator.call(4, options) }.not_to raise_error
          end
        end

        context "with symbols" do
          let(:options) { { in: %i[pending cancelled] } }

          it "excludes symbol values" do
            expect { validator.call(:pending, options) }
              .to raise_error(CMDx::ValidationError, "must not be one of: :pending, :cancelled")
          end

          it "allows non-excluded symbols" do
            expect { validator.call(:active, options) }.not_to raise_error
          end
        end

        context "with mixed types" do
          let(:options) { { in: ["string", 42, :symbol] } }

          it "excludes string value" do
            expect { validator.call("string", options) }
              .to raise_error(CMDx::ValidationError, 'must not be one of: "string", 42, :symbol')
          end

          it "excludes integer value" do
            expect { validator.call(42, options) }
              .to raise_error(CMDx::ValidationError, 'must not be one of: "string", 42, :symbol')
          end

          it "excludes symbol value" do
            expect { validator.call(:symbol, options) }
              .to raise_error(CMDx::ValidationError, 'must not be one of: "string", 42, :symbol')
          end
        end
      end

      context "with case-sensitive comparison" do
        let(:options) { { in: %w[Admin ROOT] } }

        it "is case sensitive" do
          expect { validator.call("admin", options) }.not_to raise_error
          expect { validator.call("root", options) }.not_to raise_error
          expect { validator.call("Admin", options) }
            .to raise_error(CMDx::ValidationError, 'must not be one of: "Admin", "ROOT"')
        end
      end
    end

    context "with range exclusions" do
      context "with integer range" do
        let(:options) { { in: (1..10) } }

        context "when value is within range" do
          it "raises ValidationError with default message" do
            expect { validator.call(5, options) }
              .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
          end

          it "raises error for boundary values" do
            expect { validator.call(1, options) }
              .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
            expect { validator.call(10, options) }
              .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
          end
        end

        context "when value is outside range" do
          it "does not raise error" do
            expect { validator.call(0, options) }.not_to raise_error
            expect { validator.call(11, options) }.not_to raise_error
            expect { validator.call(-5, options) }.not_to raise_error
          end
        end

        context "with custom :in_message" do
          let(:options) { { in: (18..65), in_message: "age restricted" } }

          it "uses custom message" do
            expect { validator.call(25, options) }
              .to raise_error(CMDx::ValidationError, "age restricted")
          end
        end

        context "with custom :within_message" do
          let(:options) { { within: (1..5), within_message: "not in allowed range" } }

          it "uses custom message" do
            expect { validator.call(3, options) }
              .to raise_error(CMDx::ValidationError, "not in allowed range")
          end
        end

        context "with message interpolation" do
          let(:options) { { in: (1..10), in_message: "between %<min>s and %<max>s not allowed" } }

          it "interpolates min and max into custom message" do
            expect { validator.call(5, options) }
              .to raise_error(CMDx::ValidationError, "between 1 and 10 not allowed")
          end
        end
      end

      context "with exclusive range" do
        let(:options) { { in: (1...10) } }

        it "excludes values within range but not the end" do
          expect { validator.call(9, options) }
            .to raise_error(CMDx::ValidationError, "must not be within 1 and 10")
          expect { validator.call(10, options) }.not_to raise_error
        end
      end

      context "with string range" do
        let(:options) { { in: ("a".."z") } }

        it "excludes values within string range" do
          expect { validator.call("m", options) }
            .to raise_error(CMDx::ValidationError, "must not be within a and z")
          expect { validator.call("A", options) }.not_to raise_error
        end
      end

      context "with date range" do
        let(:start_date) { Date.new(2023, 1, 1) }
        let(:end_date) { Date.new(2023, 12, 31) }
        let(:options) { { in: (start_date..end_date) } }

        it "excludes dates within range" do
          test_date = Date.new(2023, 6, 15)
          expect { validator.call(test_date, options) }
            .to raise_error(CMDx::ValidationError, "must not be within #{start_date} and #{end_date}")
        end

        it "allows dates outside range" do
          expect { validator.call(Date.new(2022, 12, 31), options) }.not_to raise_error
          expect { validator.call(Date.new(2024, 1, 1), options) }.not_to raise_error
        end
      end
    end

    context "with edge cases" do
      context "when exclusion list is empty" do
        let(:options) { { in: [] } }

        it "does not raise error for any value" do
          expect { validator.call("anything", options) }.not_to raise_error
          expect { validator.call(123, options) }.not_to raise_error
          expect { validator.call(nil, options) }.not_to raise_error
        end
      end

      context "when exclusion list is nil" do
        let(:options) { { in: nil } }

        it "does not raise error for any value" do
          expect { validator.call("anything", options) }.not_to raise_error
          expect { validator.call(123, options) }.not_to raise_error
        end
      end

      context "when testing nil value" do
        let(:options) { { in: [nil, "null"] } }

        it "excludes nil when explicitly included" do
          expect { validator.call(nil, options) }
            .to raise_error(CMDx::ValidationError, 'must not be one of: nil, "null"')
        end

        it "allows nil when not in exclusion list" do
          expect { validator.call(nil, { in: ["other"] }) }.not_to raise_error
        end
      end

      context "with object comparison using ===" do
        let(:regex_pattern) { /admin/ }
        let(:options) { { in: [regex_pattern] } }

        it "uses === for comparison with regex" do
          expect { validator.call("admin_user", options) }
            .to raise_error(CMDx::ValidationError)
          expect { validator.call("user", options) }.not_to raise_error
        end
      end

      context "when no exclusion option provided" do
        let(:options) { {} }

        it "does not raise error" do
          expect { validator.call("anything", options) }.not_to raise_error
        end
      end

      context "with both :in and :within options" do
        let(:options) { { in: %w[admin], within: %w[root] } }

        it "uses :in option when both are present" do
          expect { validator.call("admin", options) }
            .to raise_error(CMDx::ValidationError, 'must not be one of: "admin"')
          expect { validator.call("root", options) }.not_to raise_error
        end
      end
    end

    context "with custom message priority" do
      context "when multiple message options are provided" do
        let(:options) do
          {
            in: %w[test],
            message: "generic message",
            of_message: "specific of message"
          }
        end

        it "prioritizes of_message over message for arrays" do
          expect { validator.call("test", options) }
            .to raise_error(CMDx::ValidationError, "specific of message")
        end
      end

      context "with range and multiple message options" do
        let(:options) do
          {
            in: (1..5),
            message: "generic message",
            in_message: "specific in message",
            within_message: "specific within message"
          }
        end

        it "prioritizes in_message over within_message and message for ranges" do
          expect { validator.call(3, options) }
            .to raise_error(CMDx::ValidationError, "specific in message")
        end
      end
    end

    context "with internationalization" do
      it "calls Locale.t for default array exclusion message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.exclusion.of",
          values: '"admin"'
        ).and_return("localized message")

        expect { validator.call("admin", { in: %w[admin] }) }
          .to raise_error(CMDx::ValidationError, "localized message")
      end

      it "calls Locale.t for default range exclusion message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.exclusion.within",
          min: 1,
          max: 10
        ).and_return("localized range message")

        expect { validator.call(5, { in: (1..10) }) }
          .to raise_error(CMDx::ValidationError, "localized range message")
      end
    end
  end
end

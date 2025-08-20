# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion, type: :unit do
  subject(:validator) { described_class }

  describe ".call" do
    context "with array inclusions" do
      context "when using :in option" do
        let(:options) { { in: %w[admin user guest] } }

        context "when value is included" do
          it "does not raise error for included values" do
            expect { validator.call("admin", options) }.not_to raise_error
            expect { validator.call("user", options) }.not_to raise_error
            expect { validator.call("guest", options) }.not_to raise_error
          end
        end

        context "when value is not included" do
          it "raises ValidationError with default message" do
            expect { validator.call("root", options) }
              .to raise_error(CMDx::ValidationError, 'must be one of: "admin", "user", "guest"')
          end

          it "raises ValidationError for any non-included value" do
            %w[root system moderator].each do |excluded_value|
              expect { validator.call(excluded_value, options) }
                .to raise_error(CMDx::ValidationError, 'must be one of: "admin", "user", "guest"')
            end
          end
        end

        context "with custom :of_message" do
          let(:options) { { in: %w[active inactive], of_message: "must be a valid status" } }

          it "uses custom message" do
            expect { validator.call("pending", options) }
              .to raise_error(CMDx::ValidationError, "must be a valid status")
          end
        end

        context "with custom :message" do
          let(:options) { { in: %w[red green blue], message: "invalid color" } }

          it "uses custom message" do
            expect { validator.call("yellow", options) }
              .to raise_error(CMDx::ValidationError, "invalid color")
          end
        end

        context "with message interpolation" do
          let(:options) { { in: %w[small medium large], of_message: "size must be %<values>s" } }

          it "interpolates values into custom message" do
            expect { validator.call("extra_large", options) }
              .to raise_error(CMDx::ValidationError, 'size must be "small", "medium", "large"')
          end
        end
      end

      context "when using :within option" do
        let(:options) { { within: %w[draft published] } }

        context "when value is included" do
          it "does not raise error" do
            expect { validator.call("draft", options) }.not_to raise_error
            expect { validator.call("published", options) }.not_to raise_error
          end
        end

        context "when value is not included" do
          it "raises ValidationError with default message" do
            expect { validator.call("archived", options) }
              .to raise_error(CMDx::ValidationError, 'must be one of: "draft", "published"')
          end
        end
      end

      context "with different data types" do
        context "with integers" do
          let(:options) { { in: [1, 2, 3] } }

          it "includes integer values" do
            expect { validator.call(2, options) }.not_to raise_error
          end

          it "raises error for non-included integers" do
            expect { validator.call(4, options) }
              .to raise_error(CMDx::ValidationError, "must be one of: 1, 2, 3")
          end
        end

        context "with symbols" do
          let(:options) { { in: %i[pending active completed] } }

          it "includes symbol values" do
            expect { validator.call(:pending, options) }.not_to raise_error
          end

          it "raises error for non-included symbols" do
            expect { validator.call(:cancelled, options) }
              .to raise_error(CMDx::ValidationError, "must be one of: :pending, :active, :completed")
          end
        end

        context "with mixed types" do
          let(:options) { { in: ["string", 42, :symbol] } }

          it "includes string value" do
            expect { validator.call("string", options) }.not_to raise_error
          end

          it "includes integer value" do
            expect { validator.call(42, options) }.not_to raise_error
          end

          it "includes symbol value" do
            expect { validator.call(:symbol, options) }.not_to raise_error
          end

          it "raises error for non-included values" do
            expect { validator.call("other", options) }
              .to raise_error(CMDx::ValidationError, 'must be one of: "string", 42, :symbol')
          end
        end
      end

      context "with case-sensitive comparison" do
        let(:options) { { in: %w[Admin ROOT] } }

        it "is case sensitive" do
          expect { validator.call("Admin", options) }.not_to raise_error
          expect { validator.call("ROOT", options) }.not_to raise_error
          expect { validator.call("admin", options) }
            .to raise_error(CMDx::ValidationError, 'must be one of: "Admin", "ROOT"')
          expect { validator.call("root", options) }
            .to raise_error(CMDx::ValidationError, 'must be one of: "Admin", "ROOT"')
        end
      end
    end

    context "with range inclusions" do
      context "with integer range" do
        let(:options) { { in: (1..10) } }

        context "when value is within range" do
          it "does not raise error for values in range" do
            expect { validator.call(5, options) }.not_to raise_error
            expect { validator.call(1, options) }.not_to raise_error
            expect { validator.call(10, options) }.not_to raise_error
          end
        end

        context "when value is outside range" do
          it "raises ValidationError with default message" do
            expect { validator.call(0, options) }
              .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
            expect { validator.call(11, options) }
              .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
            expect { validator.call(-5, options) }
              .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
          end
        end

        context "with custom :in_message" do
          let(:options) { { in: (18..65), in_message: "age must be valid" } }

          it "uses custom message" do
            expect { validator.call(17, options) }
              .to raise_error(CMDx::ValidationError, "age must be valid")
          end
        end

        context "with custom :within_message" do
          let(:options) { { within: (1..5), within_message: "must be in allowed range" } }

          it "uses custom message" do
            expect { validator.call(6, options) }
              .to raise_error(CMDx::ValidationError, "must be in allowed range")
          end
        end

        context "with message interpolation" do
          let(:options) { { in: (1..10), in_message: "must be between %<min>s and %<max>s" } }

          it "interpolates min and max into custom message" do
            expect { validator.call(15, options) }
              .to raise_error(CMDx::ValidationError, "must be between 1 and 10")
          end
        end
      end

      context "with exclusive range" do
        let(:options) { { in: (1...10) } }

        it "includes values within range but not the end" do
          expect { validator.call(9, options) }.not_to raise_error
          expect { validator.call(10, options) }
            .to raise_error(CMDx::ValidationError, "must be within 1 and 10")
        end
      end

      context "with string range" do
        let(:options) { { in: ("a".."z") } }

        it "includes values within string range" do
          expect { validator.call("m", options) }.not_to raise_error
          expect { validator.call("A", options) }
            .to raise_error(CMDx::ValidationError, "must be within a and z")
        end
      end

      context "with date range" do
        let(:start_date) { Date.new(2023, 1, 1) }
        let(:end_date) { Date.new(2023, 12, 31) }
        let(:options) { { in: (start_date..end_date) } }

        it "includes dates within range" do
          test_date = Date.new(2023, 6, 15)
          expect { validator.call(test_date, options) }.not_to raise_error
        end

        it "raises error for dates outside range" do
          expect { validator.call(Date.new(2022, 12, 31), options) }
            .to raise_error(CMDx::ValidationError, "must be within #{start_date} and #{end_date}")
          expect { validator.call(Date.new(2024, 1, 1), options) }
            .to raise_error(CMDx::ValidationError, "must be within #{start_date} and #{end_date}")
        end
      end
    end

    context "with edge cases" do
      context "when inclusion list is empty" do
        let(:options) { { in: [] } }

        it "raises error for any value" do
          expect { validator.call("anything", options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
          expect { validator.call(123, options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
          expect { validator.call(nil, options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
        end
      end

      context "when inclusion list is nil" do
        let(:options) { { in: nil } }

        it "raises error for any value" do
          expect { validator.call("anything", options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
          expect { validator.call(123, options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
        end
      end

      context "when testing nil value" do
        let(:options) { { in: [nil, "null"] } }

        it "includes nil when explicitly included" do
          expect { validator.call(nil, options) }.not_to raise_error
        end

        it "raises error for nil when not in inclusion list" do
          expect { validator.call(nil, { in: ["other"] }) }
            .to raise_error(CMDx::ValidationError, 'must be one of: "other"')
        end
      end

      context "with object comparison using ===" do
        let(:regex_pattern) { /admin/ }
        let(:options) { { in: [regex_pattern] } }

        it "uses === for comparison with regex" do
          expect { validator.call("admin_user", options) }.not_to raise_error
          expect { validator.call("user", options) }
            .to raise_error(CMDx::ValidationError)
        end
      end

      context "when no inclusion option provided" do
        let(:options) { {} }

        it "raises error for any value" do
          expect { validator.call("anything", options) }
            .to raise_error(CMDx::ValidationError, "must be one of: ")
        end
      end

      context "with both :in and :within options" do
        let(:options) { { in: %w[admin], within: %w[root] } }

        it "uses :in option when both are present" do
          expect { validator.call("admin", options) }.not_to raise_error
          expect { validator.call("root", options) }
            .to raise_error(CMDx::ValidationError, 'must be one of: "admin"')
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
          expect { validator.call("invalid", options) }
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
          expect { validator.call(10, options) }
            .to raise_error(CMDx::ValidationError, "specific in message")
        end
      end
    end

    context "with internationalization" do
      it "calls Locale.t for default array inclusion message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.inclusion.of",
          values: '"valid"'
        ).and_return("localized message")

        expect { validator.call("invalid", { in: %w[valid] }) }
          .to raise_error(CMDx::ValidationError, "localized message")
      end

      it "calls Locale.t for default range inclusion message" do
        expect(CMDx::Locale).to receive(:t).with(
          "cmdx.validators.inclusion.within",
          min: 1,
          max: 10
        ).and_return("localized range message")

        expect { validator.call(15, { in: (1..10) }) }
          .to raise_error(CMDx::ValidationError, "localized range message")
      end
    end
  end
end

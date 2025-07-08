# frozen_string_literal: true

require "spec_helper"
require "uri"

RSpec.describe CMDx::ValidatorRegistry do
  subject(:registry) { described_class.new }

  describe "#initialize" do
    context "with no arguments" do
      it "creates registry with default validators only" do
        expect(registry.registry).not_to be_empty
      end
    end
  end

  describe "#register" do
    let(:email_validator) { proc { |v, _o| v.include?("@") } }

    it "registers a new validator" do
      registry.register(:email, email_validator)
      expect(registry.registry[:email]).to eq(email_validator)
    end

    it "overwrites existing validators" do
      registry.register(:presence, email_validator)
      expect(registry.registry[:presence]).to eq(email_validator)
    end

    it "returns self for method chaining" do
      result = registry.register(:email, email_validator)
      expect(result).to be(registry)
    end

    it "supports method chaining" do
      phone_validator = proc { |value, _options| value.match?(/\d{3}-\d{3}-\d{4}/) }

      registry.register(:email, email_validator)
              .register(:phone, phone_validator)

      expect(registry.registry[:email]).to eq(email_validator)
      expect(registry.registry[:phone]).to eq(phone_validator)
    end

    context "with different validator types" do
      it "registers proc validators" do
        proc_validator = proc { |v, _o| !v.strip.empty? }
        registry.register(:strip, proc_validator)
        expect(registry.registry[:strip]).to eq(proc_validator)
      end

      it "registers lambda validators" do
        lambda_validator = ->(v, _o) { !v.upcase.empty? }
        registry.register(:upcase, lambda_validator)
        expect(registry.registry[:upcase]).to eq(lambda_validator)
      end

      it "registers class validators" do
        class_validator = double("Validator")
        allow(class_validator).to receive(:call)
        registry.register(:email, class_validator)
        expect(registry.registry[:email]).to eq(class_validator)
      end
    end
  end

  describe "#call" do
    context "with built-in validators" do
      it "applies presence validation" do
        expect { registry.call(:presence, "hello", presence: true) }.not_to raise_error
      end

      it "applies format validation" do
        expect { registry.call(:format, "user@example.com", format: { with: /@/ }) }.not_to raise_error
      end

      it "applies numeric validation" do
        expect { registry.call(:numeric, 42, numeric: { min: 0 }) }.not_to raise_error
      end

      it "applies length validation" do
        expect { registry.call(:length, "hello", length: { min: 3 }) }.not_to raise_error
      end

      it "applies inclusion validation" do
        expect { registry.call(:inclusion, "active", inclusion: { in: %w[active inactive] }) }.not_to raise_error
      end

      it "applies exclusion validation" do
        expect { registry.call(:exclusion, "active", exclusion: { in: %w[deleted] }) }.not_to raise_error
      end

      it "passes options to built-in validators" do
        expect { registry.call(:length, "hello", length: { min: 3, max: 10 }) }.not_to raise_error
      end
    end

    context "with custom validators" do
      let(:email_validator) do
        proc { |value, _options|
          raise CMDx::ValidationError, "must contain @" unless value.include?("@")
        }
      end
      let(:phone_validator) do
        proc { |value, _options|
          raise CMDx::ValidationError, "must be in format XXX-XXX-XXXX" unless value.match?(/\d{3}-\d{3}-\d{4}/)
        }
      end

      before do
        registry.register(:email, email_validator)
        registry.register(:phone, phone_validator)
      end

      it "applies custom proc validators" do
        expect { registry.call(:email, "user@example.com", email: true) }.not_to raise_error
      end

      it "fails custom validators when validation fails" do
        expect { registry.call(:email, "invalid-email", email: true) }.to raise_error(CMDx::ValidationError, "must contain @")
      end

      it "applies custom validators with options" do
        options_validator = proc { |value, options|
          min_length = options.dig(:email, :min_length) || 0
          raise CMDx::ValidationError, "email must be at least #{min_length} characters and contain @" unless value.length >= min_length && value.include?("@")
        }

        registry.register(:email, options_validator)

        expect { registry.call(:email, "user@example.com", email: { min_length: 5 }) }.not_to raise_error
      end

      it "applies validator classes with call method" do
        validator_class = double("ValidatorClass")
        allow(validator_class).to receive(:call).and_return(nil)

        registry.register(:class_validator, validator_class)
        registry.call(:class_validator, "test", class_validator: true)

        expect(validator_class).to have_received(:call).with("test", class_validator: true)
      end
    end

    context "with unknown validator types" do
      it "raises UnknownValidatorError for unregistered types" do
        expect { registry.call(:unknown, "value", unknown: true) }
          .to raise_error(CMDx::UnknownValidatorError, "unknown validator unknown")
      end

      it "raises UnknownValidatorError with descriptive message" do
        expect { registry.call(:missing_type, "value", missing_type: true) }
          .to raise_error(CMDx::UnknownValidatorError, "unknown validator missing_type")
      end
    end

    context "when error handling within validators" do
      it "propagates validation errors" do
        failing_validator = proc { |_value, _options| raise CMDx::ValidationError, "validation failed" }
        registry.register(:failing, failing_validator)

        expect { registry.call(:failing, "value", failing: true) }
          .to raise_error(CMDx::ValidationError, "validation failed")
      end

      it "handles nil validator gracefully" do
        # Directly set nil validator to bypass type validation
        registry.instance_variable_get(:@registry)[:nil_validator] = nil

        expect { registry.call(:nil_validator, "value", nil_validator: true) }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe "integration with built-in validators" do
    it "supports all default validator types" do
      test_cases = {
        presence: ["hello", { presence: true }],
        format: ["user@example.com", { format: { with: /@/ } }],
        length: ["hello", { length: { min: 3 } }],
        numeric: [42, { numeric: { min: 0 } }],
        inclusion: ["active", { inclusion: { in: %w[active inactive] } }],
        exclusion: ["active", { exclusion: { in: %w[deleted] } }]
      }

      described_class.new.registry.each_key do |type|
        test_value, options = test_cases[type]
        expect { registry.call(type, test_value, options) }.not_to raise_error
      end
    end

    it "maintains isolation between registry instances" do
      registry1 = described_class.new
      registry2 = described_class.new

      custom_validator = proc { |v, _o|
        raise CMDx::ValidationError, "value must be custom" unless v == "custom"
      }
      registry1.register(:custom_validator, custom_validator)

      expect { registry1.call(:custom_validator, "custom", custom_validator: true) }.not_to raise_error
      expect { registry2.call(:custom_validator, "custom", custom_validator: true) }
        .to raise_error(CMDx::UnknownValidatorError)
    end
  end

  describe "real-world usage patterns" do
    it "supports common domain validators" do
      # Email validation
      registry.register(:email, proc { |value, options|
        domain = options.dig(:email, :domain) if options[:email].is_a?(Hash)
        raise CMDx::ValidationError, "invalid email format" unless value.include?("@") && (domain.nil? || value.end_with?("@#{domain}"))
      })

      # Phone number validation
      registry.register(:phone, proc { |value, options|
        country = options.dig(:phone, :country) if options[:phone].is_a?(Hash)
        country ||= "US"
        valid = case country
                when "US"
                  value.match?(/\A\d{3}-\d{3}-\d{4}\z/)
                else
                  value.match?(/\A\+?\d{10,15}\z/)
                end

        raise CMDx::ValidationError, "invalid phone format" unless valid
      })

      # URL validation
      registry.register(:url, proc { |value, options|
        secure_only = options.dig(:url, :secure_only) if options[:url].is_a?(Hash)
        secure_only ||= false
        uri = begin
          URI.parse(value)
        rescue StandardError
          nil
        end
        raise CMDx::ValidationError, "invalid URL format" unless uri && (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) && (!secure_only || uri.scheme == "https")
      })

      expect { registry.call(:email, "user@example.com", email: true) }.not_to raise_error
      expect { registry.call(:email, "user@company.com", email: { domain: "company.com" }) }.not_to raise_error
      expect { registry.call(:phone, "555-123-4567", phone: { country: "US" }) }.not_to raise_error
      expect { registry.call(:url, "https://example.com", url: { secure_only: true }) }.not_to raise_error
    end

    it "supports age validation with complex logic" do
      registry.register(:age, proc { |value, options|
        min_age = options.dig(:age, :min_age) || 0
        max_age = options.dig(:age, :max_age) || 150
        adult_only = options.dig(:age, :adult_only) || false

        raise CMDx::ValidationError, "age must be between #{min_age} and #{max_age}" unless value.is_a?(Integer) && value >= min_age && value <= max_age

        raise CMDx::ValidationError, "must be at least 18 years old" if adult_only && value < 18
      })

      expect { registry.call(:age, 25, age: { min_age: 18, adult_only: true }) }.not_to raise_error
      expect { registry.call(:age, 16, age: { adult_only: true }) }.to raise_error(CMDx::ValidationError, "must be at least 18 years old")
    end

    it "supports credit card validation with options" do
      registry.register(:credit_card, proc { |value, options|
        types = options.dig(:credit_card, :types) || %w[visa mastercard amex]
        cleaned = value.gsub(/\D/, "")

        valid = case cleaned.length
                when 15
                  types.include?("amex") && cleaned.match?(/\A3[47]/)
                when 16
                  (types.include?("visa") && cleaned.start_with?("4")) ||
                  (types.include?("mastercard") && cleaned.match?(/\A5[1-5]/))
                else
                  false
                end

        raise CMDx::ValidationError, "invalid credit card number" unless valid
      })

      expect { registry.call(:credit_card, "4111-1111-1111-1111", credit_card: { types: %w[visa] }) }.not_to raise_error
      expect { registry.call(:credit_card, "3782-8224-6310-005", credit_card: { types: %w[amex] }) }.not_to raise_error
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoercionRegistry do
  subject(:registry) { described_class.new }

  describe "#initialize" do
    context "with no arguments" do
      it "creates registry with default coercions" do
        expect(registry.registry).not_to be_empty
      end
    end
  end

  describe "#register" do
    let(:email_coercion) { proc(&:downcase) }

    it "registers a new coercion" do
      registry.register(:email, email_coercion)
      expect(registry.registry[:email]).to eq(email_coercion)
    end

    it "overwrites existing coercions" do
      registry.register(:integer, email_coercion)
      expect(registry.registry[:integer]).to eq(email_coercion)
    end

    it "returns self for method chaining" do
      result = registry.register(:email, email_coercion)
      expect(result).to be(registry)
    end

    it "supports method chaining" do
      phone_coercion = proc { |value| value.gsub(/\D/, "") }

      registry.register(:email, email_coercion)
              .register(:phone, phone_coercion)

      expect(registry.registry[:email]).to eq(email_coercion)
      expect(registry.registry[:phone]).to eq(phone_coercion)
    end

    context "with different coercion types" do
      it "registers proc coercions" do
        proc_coercion = proc(&:strip)
        registry.register(:strip, proc_coercion)
        expect(registry.registry[:strip]).to eq(proc_coercion)
      end

      it "registers lambda coercions" do
        lambda_coercion = lambda(&:upcase)
        registry.register(:upcase, lambda_coercion)
        expect(registry.registry[:upcase]).to eq(lambda_coercion)
      end

      it "registers class coercions" do
        class_coercion = double("Coercion")
        allow(class_coercion).to receive(:call)
        registry.register(:custom, class_coercion)
        expect(registry.registry[:custom]).to eq(class_coercion)
      end
    end
  end

  describe "#call" do
    let(:registry) { described_class.new }
    let(:task) { double("Task") }

    before do
      allow(task).to receive(:cmdx_try)
    end

    context "with built-in coercions" do
      it "applies integer coercion" do
        result = registry.call(task, :integer, "123")
        expect(result).to eq(123)
      end

      it "applies boolean coercion" do
        expect(registry.call(task, :boolean, "true")).to be(true)
        expect(registry.call(task, :boolean, "false")).to be(false)
      end

      it "applies string coercion" do
        result = registry.call(task, :string, 123)
        expect(result).to eq("123")
      end

      it "applies virtual coercion (no change)" do
        input = { key: "value" }
        result = registry.call(task, :virtual, input)
        expect(result).to be(input)
      end
    end

    context "with custom coercions" do
      let(:email_coercion) do
        Class.new do
          def self.call(value, _options)
            value.to_s.downcase.strip
          end
        end
      end

      before do
        registry.register(:email, email_coercion)
      end

      it "applies custom proc coercions" do
        expect(registry.call(task, :email, "  USER@EXAMPLE.COM  ")).to eq("user@example.com")
      end

      it "applies custom coercions with options" do
        options_coercion = Class.new do
          def self.call(value, options)
            suffix = options.dig(:email_with_suffix, :suffix) || ""
            "#{value.to_s.downcase}#{suffix}"
          end
        end

        registry.register(:email_with_suffix, options_coercion)

        result = registry.call(task, :email_with_suffix, "USER", email_with_suffix: { suffix: "@example.com" })
        expect(result).to eq("user@example.com")
      end

      it "applies coercion classes with call method" do
        coercion_class = double("CoercionClass")
        allow(coercion_class).to receive(:call).and_return("coerced_value")

        registry.register(:class_coercion, coercion_class)
        result = registry.call(task, :class_coercion, "input", class_coercion: true)

        expect(coercion_class).to have_received(:call).with("input", class_coercion: true)
        expect(result).to eq("coerced_value")
      end
    end

    context "with unknown coercion types" do
      it "raises UnknownCoercionError for unregistered types" do
        expect { registry.call(task, :unknown, "value", unknown: true) }
          .to raise_error(CMDx::UnknownCoercionError, "unknown coercion unknown")
      end

      it "raises UnknownCoercionError with descriptive message" do
        expect { registry.call(task, :missing_type, "value", missing_type: true) }
          .to raise_error(CMDx::UnknownCoercionError, "unknown coercion missing_type")
      end
    end

    context "when error handling within coercions" do
      it "propagates coercion errors" do
        failing_coercion = Class.new do
          def self.call(_value, _options)
            raise CMDx::CoercionError, "coercion failed"
          end
        end
        registry.register(:failing, failing_coercion)

        expect { registry.call(task, :failing, "value", failing: true) }
          .to raise_error(CMDx::CoercionError, "coercion failed")
      end

      it "handles nil coercion gracefully" do
        # Directly set nil coercion to bypass type validation
        registry.instance_variable_get(:@registry)[:nil_coercion] = nil

        expect { registry.call(task, :nil_coercion, "value", nil_coercion: true) }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe "integration with built-in coercions" do
    let(:task) { double("Task") }

    before do
      allow(task).to receive(:cmdx_try)
    end

    it "supports all default coercion types" do
      test_cases = {
        array: "[1,2,3]",
        big_decimal: "123.456",
        boolean: "true",
        complex: "1+2i",
        date: "2023-01-01",
        datetime: "2023-01-01T12:00:00",
        float: "123.456",
        hash: "{\"key\":\"value\"}",
        integer: "123",
        rational: "3/4",
        string: "test",
        time: "12:00:00",
        virtual: "unchanged"
      }

      registry = described_class.new
      described_class.new.registry.each_key do |type|
        test_value = test_cases[type]
        next if test_value.nil?

        expect { registry.call(task, type, test_value) }.not_to raise_error
      end
    end

    it "maintains isolation between registry instances" do
      registry1 = described_class.new
      registry2 = described_class.new

      custom_coercion = Class.new do
        def self.call(value, _options)
          value.to_s.upcase
        end
      end
      registry1.register(:custom_coercion, custom_coercion)

      expect(registry1.call(task, :custom_coercion, "test")).to eq("TEST")
      expect { registry2.call(task, :custom_coercion, "test") }
        .to raise_error(CMDx::UnknownCoercionError)
    end
  end

  describe "real-world usage patterns" do
    let(:registry) { described_class.new }
    let(:task) { double("Task") }

    before do
      allow(task).to receive(:cmdx_try)
    end

    it "supports common domain coercions" do
      # Email coercion
      registry.register(:email, Class.new do
        def self.call(value, options)
          domain = options.dig(:email, :domain) if options[:email].is_a?(Hash)
          email = value.to_s.downcase.strip
          raise CMDx::CoercionError, "invalid email" unless email.include?("@")
          raise CMDx::CoercionError, "wrong domain" if domain && !email.end_with?("@#{domain}")

          email
        end
      end)

      expect(registry.call(task, :email, "USER@EXAMPLE.COM")).to eq("user@example.com")
      expect(registry.call(task, :email, "user@company.com", email: { domain: "company.com" })).to eq("user@company.com")
    end

    it "supports money/currency coercions with BigDecimal" do
      registry.register(:money, Class.new do
        def self.call(value, options)
          currency = options.dig(:money, :currency) || "USD"
          amount = BigDecimal(value.to_s)
          { amount: amount, currency: currency }
        end
      end)

      result = registry.call(task, :money, "99.99", money: { currency: "EUR" })
      expect(result[:amount]).to eq(BigDecimal("99.99"))
      expect(result[:currency]).to eq("EUR")
    end

    it "supports tag parsing with options" do
      registry.register(:tags, Class.new do
        def self.call(value, options)
          separator = options.dig(:tags, :separator) || ","
          normalize = options.dig(:tags, :normalize) || false
          tags = value.to_s.split(separator).map(&:strip)
          normalize ? tags.map(&:downcase) : tags
        end
      end)

      result = registry.call(task, :tags, "Ruby, Rails, API", tags: { separator: ",", normalize: true })
      expect(result).to eq(%w[ruby rails api])
    end
  end
end

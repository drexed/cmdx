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
    context "with built-in coercions" do
      it "applies integer coercion" do
        expect(registry.call(:integer, "123")).to eq(123)
      end

      it "applies boolean coercion" do
        expect(registry.call(:boolean, "true")).to be true
        expect(registry.call(:boolean, "false")).to be false
      end

      it "applies string coercion" do
        expect(registry.call(:string, 123)).to eq("123")
      end

      it "applies virtual coercion (no change)" do
        value = { test: "data" }
        expect(registry.call(:virtual, value)).to eq(value)
      end

      it "passes options to built-in coercions" do
        # Test with date coercion that supports format option
        formatted_date = registry.call(:date, "25/12/2023", format: "%d/%m/%Y")
        expect(formatted_date).to be_a(Date)
        expect(formatted_date.year).to eq(2023)
        expect(formatted_date.month).to eq(12)
        expect(formatted_date.day).to eq(25)
      end
    end

    context "with custom coercions" do
      let(:email_coercion) { proc { |value| value.downcase.strip } }
      let(:phone_coercion) { proc { |value| value.gsub(/\D/, "") } }

      before do
        registry.register(:email, email_coercion)
        registry.register(:phone, phone_coercion)
      end

      it "applies custom proc coercions" do
        expect(registry.call(:email, "  USER@EXAMPLE.COM  ")).to eq("user@example.com")
        expect(registry.call(:phone, "(555) 123-4567")).to eq("5551234567")
      end

      it "applies custom coercions with options" do
        options_coercion = proc { |value, options|
          result = value.to_s
          result = result.upcase if options[:upcase]
          result = result.reverse if options[:reverse]
          result
        }

        registry.register(:flexible, options_coercion)

        expect(registry.call(:flexible, "hello")).to eq("hello")
        expect(registry.call(:flexible, "hello", upcase: true)).to eq("HELLO")
        expect(registry.call(:flexible, "hello", reverse: true)).to eq("olleh")
        expect(registry.call(:flexible, "hello", upcase: true, reverse: true)).to eq("OLLEH")
      end

      it "applies coercion classes with call method" do
        coercion_class = double("CoercionClass")
        allow(coercion_class).to receive(:call).with("test", {}).and_return("transformed")

        registry.register(:class_coercion, coercion_class)
        result = registry.call(:class_coercion, "test")

        expect(result).to eq("transformed")
        expect(coercion_class).to have_received(:call).with("test", {})
      end
    end

    context "with unknown coercion types" do
      it "raises UnknownCoercionError for unregistered types" do
        expect { registry.call(:unknown, "value") }
          .to raise_error(CMDx::UnknownCoercionError, "unknown coercion unknown")
      end

      it "raises UnknownCoercionError with descriptive message" do
        expect { registry.call(:missing_type, "value") }
          .to raise_error(CMDx::UnknownCoercionError, "unknown coercion missing_type")
      end
    end

    context "when error handling within coercions" do
      it "propagates coercion errors" do
        failing_coercion = proc { |_value| raise StandardError, "coercion failed" }
        registry.register(:failing, failing_coercion)

        expect { registry.call(:failing, "value") }
          .to raise_error(StandardError, "coercion failed")
      end

      it "handles nil coercion gracefully" do
        # Directly set nil coercion to bypass type validation
        registry.instance_variable_get(:@registry)[:nil_coercion] = nil

        expect { registry.call(:nil_coercion, "value") }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe "integration with built-in coercions" do
    it "supports all default coercion types" do
      test_values = {
        array: "[1,2,3]",
        big_decimal: "123.45",
        boolean: "true",
        complex: "1+2i",
        date: "2023-12-25",
        datetime: "2023-12-25 15:30:00",
        float: "123.45",
        hash: '{"key": "value"}',
        integer: "123",
        rational: "1/2",
        string: "test",
        time: "2023-12-25 15:30:00",
        virtual: "anything"
      }

      described_class.new.registry.each_key do |type|
        test_value = test_values[type]
        expect { registry.call(type, test_value) }.not_to raise_error
      end
    end

    it "maintains isolation between registry instances" do
      registry1 = described_class.new
      registry2 = described_class.new

      custom_coercion = proc { |v| "custom_#{v}" }
      registry1.register(:custom, custom_coercion)

      expect(registry1.call(:custom, "test")).to eq("custom_test")
      expect { registry2.call(:custom, "test") }
        .to raise_error(CMDx::UnknownCoercionError)
    end
  end

  describe "real-world usage patterns" do
    it "supports common domain coercions" do
      # Email normalization
      registry.register(:email, proc { |value|
        value.to_s.downcase.strip
      })

      # Phone number cleaning
      registry.register(:phone, proc { |value|
        value.to_s.gsub(/\D/, "")
      })

      # URL slug generation
      registry.register(:slug, proc { |value|
        value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").squeeze("-").gsub(/^-+|-+$/, "")
      })

      expect(registry.call(:email, "  USER@EXAMPLE.COM  ")).to eq("user@example.com")
      expect(registry.call(:phone, "(555) 123-4567")).to eq("5551234567")
      expect(registry.call(:slug, "My Great Blog Post!")).to eq("my-great-blog-post")
    end

    it "supports money/currency coercions with BigDecimal" do
      registry.register(:money, proc { |value|
        if value.is_a?(String)
          clean_value = value.gsub(/[$,]/, "")
          BigDecimal(clean_value)
        else
          BigDecimal(value.to_s)
        end
      })

      expect(registry.call(:money, "$123.45")).to eq(BigDecimal("123.45"))
      expect(registry.call(:money, "1,234.56")).to eq(BigDecimal("1234.56"))
      expect(registry.call(:money, 99.99)).to eq(BigDecimal("99.99"))
    end

    it "supports tag parsing with options" do
      registry.register(:tags, proc { |value, options|
        separator = options[:separator] || ","
        max_tags = options[:max_tags] || 10

        tags = value.to_s.split(separator).map(&:strip).reject(&:empty?)
        tags = tags.first(max_tags) if max_tags
        tags.uniq
      })

      expect(registry.call(:tags, "ruby,rails,web")).to eq(%w[ruby rails web])
      expect(registry.call(:tags, "a|b|c", separator: "|")).to eq(%w[a b c])
      expect(registry.call(:tags, "1,2,3,4,5", max_tags: 3)).to eq(%w[1 2 3])
    end
  end
end

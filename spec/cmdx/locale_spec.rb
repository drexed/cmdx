# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Locale do
  subject(:translate_result) { described_class.translate(key, **options) }

  describe "#translate" do
    context "when I18n is not defined" do
      before { hide_const("I18n") }

      context "with a valid key" do
        let(:key) { "cmdx.validators.presence" }
        let(:options) { {} }

        it "returns the default translation from EN" do
          expect(translate_result).to eq("cannot be empty")
        end
      end

      context "with a nested key" do
        let(:key) { "cmdx.validators.length.min" }
        let(:options) { { min: 5 } }

        it "returns the interpolated message" do
          expect(translate_result).to eq("length must be at least 5")
        end
      end

      context "with a key that has multiple interpolations" do
        let(:key) { "cmdx.validators.length.within" }
        let(:options) { { min: 3, max: 10 } }

        it "interpolates all variables" do
          expect(translate_result).to eq("length must be within 3 and 10")
        end
      end

      context "with a non-existent key" do
        let(:key) { "cmdx.non.existent.key" }
        let(:options) { {} }

        it "returns a missing translation message" do
          expect(translate_result).to eq("Translation missing: cmdx.non.existent.key")
        end
      end

      context "with an explicit default option" do
        let(:key) { "cmdx.non.existent.key" }
        let(:options) { { default: "Custom default message" } }

        it "uses the provided default" do
          expect(translate_result).to eq("Custom default message")
        end
      end

      context "with an explicit default option and interpolation" do
        let(:key) { "cmdx.non.existent.key" }
        let(:options) { { default: "Custom %<value>s message", value: "test" } }

        it "interpolates the custom default" do
          expect(translate_result).to eq("Custom test message")
        end
      end

      context "with a non-string default" do
        let(:key) { "cmdx.non.existent.key" }
        let(:options) { { default: [:array, "value"] } }

        it "returns the default as-is" do
          expect(translate_result).to eq([:array, "value"])
        end
      end

      context "with a symbol key" do
        let(:key) { :"cmdx.validators.presence" }
        let(:options) { {} }

        it "converts the symbol to string and translates" do
          expect(translate_result).to eq("cannot be empty")
        end
      end

      context "with a key containing dots" do
        let(:key) { "cmdx.types.big_decimal" }
        let(:options) { {} }

        it "properly navigates nested hash structure" do
          expect(translate_result).to eq("big decimal")
        end
      end

      context "with empty options" do
        let(:key) { "cmdx.validators.format" }
        let(:options) { {} }

        it "returns the translation without interpolation" do
          expect(translate_result).to eq("is an invalid format")
        end
      end

      context "with extra options that are not in the template" do
        let(:key) { "cmdx.validators.format" }
        let(:options) { { extra: "value", another: "option" } }

        it "ignores extra options and returns the translation" do
          expect(translate_result).to eq("is an invalid format")
        end
      end
    end

    context "when I18n is defined" do
      let(:i18n_double) { class_double("I18n") }
      let(:key) { "cmdx.validators.presence" }
      let(:options) { { locale: :es } }

      before do
        stub_const("I18n", i18n_double)
        allow(i18n_double).to receive(:t).and_return("no puede estar vacío")
      end

      it "delegates to I18n.t with the key and options" do
        translate_result
        expect(i18n_double).to have_received(:t).with(key, **options, default: "cannot be empty")
        expect(translate_result).to eq("no puede estar vacío")
      end

      context "when the key is not found in EN" do
        let(:key) { "some.unknown.key" }

        it "sets default to nil and delegates to I18n" do
          translate_result
          expect(i18n_double).to have_received(:t).with(key, **options, default: nil)
        end
      end

      context "with an explicit default option" do
        let(:options) { { default: "Custom default", locale: :es } }

        it "preserves the provided default" do
          translate_result
          expect(i18n_double).to have_received(:t).with(key, **options)
        end
      end
    end
  end
end

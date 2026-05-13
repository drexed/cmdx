# frozen_string_literal: true

require "tmpdir"

RSpec.describe CMDx::I18nProxy do
  let(:proxy) { described_class.new }

  describe "#translate" do
    context "when I18n is defined" do
      it "delegates to I18n.translate" do
        fake_i18n = Module.new do
          def self.translate(key, **opts) = [key, opts]
        end
        stub_const("I18n", fake_i18n)

        expect(proxy.translate(:hello, name: "world")).to eq([:hello, { name: "world" }])
      end
    end

    context "when I18n is not defined" do
      before { hide_const("I18n") }

      it "interpolates a string default with options" do
        result = proxy.translate(:custom, default: "hi %{name}", name: "Ada")
        expect(result).to eq("hi Ada")
      end

      it "returns a missing-translation message when the key is absent" do
        allow(proxy).to receive(:translation_default).and_return(nil)
        expect(proxy.translate("nope.nothing")).to eq("Translation missing: nope.nothing")
      end

      it "returns a non-string, non-nil default verbatim" do
        expect(proxy.translate(:x, default: %w[a b])).to eq(%w[a b])
      end
    end

    it "delegates to #translate with the same arguments" do
      allow(proxy).to receive(:translation_default).and_return(nil)
      expect(proxy.t("nope.nothing")).to eq(proxy.translate("nope.nothing"))
    end
  end

  describe ".translate" do
    before { hide_const("I18n") }

    it "memoizes an internal proxy and delegates to it" do
      expect(described_class.translate("cmdx.faults.unspecified")).to be_a(String)
    end

    it "delegates to .translate with the same arguments" do
      expect(described_class.t("cmdx.faults.unspecified")).to eq(described_class.translate("cmdx.faults.unspecified"))
    end
  end

  describe "translation_default" do
    before { hide_const("I18n") }

    it "loads the en locale file and returns the nested value" do
      value = proxy.translate("cmdx.faults.unspecified")
      expect(value).to be_a(String)
      expect(value).not_to be_empty
    end

    it "caches successive lookups of the same key" do
      proxy.translate("cmdx.faults.unspecified")
      defaults = proxy.instance_variable_get(:@defaults)
      expect(defaults.keys).to include("en.cmdx.faults.unspecified")
    end
  end

  describe ".tr" do
    before { hide_const("I18n") }

    it "returns the unspecified default when the reason is nil" do
      expect(described_class.tr(nil))
        .to eq(described_class.t("cmdx.reasons.unspecified"))
    end

    it "returns the literal reason when no translation key matches" do
      expect(described_class.tr("Payment failed")).to eq("Payment failed")
    end

    it "resolves the reason through translation when a matching key exists" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "en.yml"), { "en" => { "payment_failed" => "Payment failed" } }.to_yaml)
        described_class.register(dir)

        expect(described_class.tr("payment_failed")).to eq("Payment failed")
      end
    ensure
      described_class.instance_variable_set(:@locale_paths, nil)
      described_class.instance_variable_set(:@proxy, nil)
    end
  end

  describe ".locale_paths / .register" do
    let(:default_paths) { [File.expand_path("../../lib/cmdx/../locales", __dir__)] }

    around do |example|
      original = described_class.instance_variable_get(:@locale_paths)
      described_class.instance_variable_set(:@locale_paths, nil)
      described_class.instance_variable_set(:@proxy, nil)
      example.run
    ensure
      described_class.instance_variable_set(:@locale_paths, original)
      described_class.instance_variable_set(:@proxy, nil)
    end

    it "seeds locale_paths with cmdx's own locales directory" do
      expect(described_class.locale_paths.size).to eq(1)
      expect(described_class.locale_paths.first).to match(%r{/lib/locales\z})
    end

    it "appends a registered path and is idempotent" do
      Dir.mktmpdir do |dir|
        described_class.register(dir)
        described_class.register(dir)
        expect(described_class.locale_paths.last).to eq(dir)
        expect(described_class.locale_paths.count(dir)).to eq(1)
      end
    end

    it "resets the memoized proxy when a path is registered" do
      described_class.instance_variable_set(:@proxy, :sentinel)
      Dir.mktmpdir do |dir|
        described_class.register(dir)
      end
      expect(described_class.instance_variable_get(:@proxy)).to be_nil
    end

    context "when resolving a locale only present in an external path" do
      before { hide_const("I18n") }

      it "finds the translation via the registered path" do
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "fr.yml"), { "fr" => { "greeting" => "bonjour %{name}" } }.to_yaml)
          described_class.register(dir)

          CMDx.configuration.default_locale = "fr"
          expect(proxy.translate("greeting", name: "Ada")).to eq("bonjour Ada")
        end
      end
    end

    context "when a locale key exists in multiple paths" do
      before { hide_const("I18n") }

      it "prefers the most-recently-registered path" do
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "en.yml"), { "en" => { "custom" => { "key" => "override" } } }.to_yaml)
          described_class.register(dir)

          expect(proxy.translate("custom.key")).to eq("override")
        end
      end

      it "deep-merges nested keys so external paths can override individual leaves" do
        Dir.mktmpdir do |dir|
          # Override a single nested key without restating the whole tree.
          File.write(
            File.join(dir, "en.yml"),
            { "en" => { "cmdx" => { "validators" => { "format" => "OVERRIDDEN" } } } }.to_yaml
          )
          described_class.register(dir)

          expect(proxy.translate("cmdx.validators.format")).to eq("OVERRIDDEN")
          # Sibling key from the bundled cmdx locale must still resolve.
          expect(proxy.translate("cmdx.validators.presence")).to be_a(String)
          expect(proxy.translate("cmdx.validators.presence")).not_to be_empty
        end
      end
    end
  end
end

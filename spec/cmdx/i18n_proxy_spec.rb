# frozen_string_literal: true

require "spec_helper"
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

    it "is aliased as #t" do
      expect(proxy.method(:t)).to eq(proxy.method(:translate))
    end
  end

  describe ".translate" do
    before { hide_const("I18n") }

    it "memoizes an internal proxy and delegates to it" do
      expect(described_class.translate("cmdx.faults.unspecified")).to be_a(String)
    end

    it "is aliased as .t" do
      expect(described_class.method(:t)).to eq(described_class.method(:translate))
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
    end
  end
end

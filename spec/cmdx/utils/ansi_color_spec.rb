# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::AnsiColor do
  describe ".call" do
    context "with valid color and default mode" do
      it "returns text wrapped with ANSI escape codes for red color" do
        result = described_class.call("Error", color: :red)

        expect(result).to eq("\e[0;31;49mError\e[0m")
      end

      it "returns text wrapped with ANSI escape codes for green color" do
        result = described_class.call("Success", color: :green)

        expect(result).to eq("\e[0;32;49mSuccess\e[0m")
      end

      it "returns text wrapped with ANSI escape codes for blue color" do
        result = described_class.call("Info", color: :blue)

        expect(result).to eq("\e[0;34;49mInfo\e[0m")
      end

      it "returns text wrapped with ANSI escape codes for yellow color" do
        result = described_class.call("Warning", color: :yellow)

        expect(result).to eq("\e[0;33;49mWarning\e[0m")
      end

      it "returns text wrapped with ANSI escape codes for light colors" do
        result = described_class.call("Debug", color: :light_black)

        expect(result).to eq("\e[0;90;49mDebug\e[0m")
      end
    end

    context "with valid color and custom mode" do
      it "returns text with bold mode applied" do
        result = described_class.call("Important", color: :red, mode: :bold)

        expect(result).to eq("\e[1;31;49mImportant\e[0m")
      end

      it "returns text with italic mode applied" do
        result = described_class.call("Emphasis", color: :blue, mode: :italic)

        expect(result).to eq("\e[3;34;49mEmphasis\e[0m")
      end

      it "returns text with underline mode applied" do
        result = described_class.call("Link", color: :cyan, mode: :underline)

        expect(result).to eq("\e[4;36;49mLink\e[0m")
      end

      it "returns text with dim mode applied" do
        result = described_class.call("Subtle", color: :white, mode: :dim)

        expect(result).to eq("\e[2;37;49mSubtle\e[0m")
      end

      it "returns text with strike mode applied" do
        result = described_class.call("Deleted", color: :red, mode: :strike)

        expect(result).to eq("\e[9;31;49mDeleted\e[0m")
      end
    end

    context "with various color combinations" do
      it "handles black color correctly" do
        result = described_class.call("Text", color: :black)

        expect(result).to eq("\e[0;30;49mText\e[0m")
      end

      it "handles magenta color correctly" do
        result = described_class.call("Text", color: :magenta)

        expect(result).to eq("\e[0;35;49mText\e[0m")
      end

      it "handles cyan color correctly" do
        result = described_class.call("Text", color: :cyan)

        expect(result).to eq("\e[0;36;49mText\e[0m")
      end

      it "handles white color correctly" do
        result = described_class.call("Text", color: :white)

        expect(result).to eq("\e[0;37;49mText\e[0m")
      end

      it "handles default color correctly" do
        result = described_class.call("Text", color: :default)

        expect(result).to eq("\e[0;39;49mText\e[0m")
      end
    end

    context "with various mode combinations" do
      it "handles blink mode correctly" do
        result = described_class.call("Blinking", color: :red, mode: :blink)

        expect(result).to eq("\e[5;31;49mBlinking\e[0m")
      end

      it "handles invert mode correctly" do
        result = described_class.call("Inverted", color: :blue, mode: :invert)

        expect(result).to eq("\e[7;34;49mInverted\e[0m")
      end

      it "handles hide mode correctly" do
        result = described_class.call("Hidden", color: :green, mode: :hide)

        expect(result).to eq("\e[8;32;49mHidden\e[0m")
      end

      it "handles double_underline mode correctly" do
        result = described_class.call("DoubleUnder", color: :yellow, mode: :double_underline)

        expect(result).to eq("\e[20;33;49mDoubleUnder\e[0m")
      end
    end

    context "with special text content" do
      it "handles empty string" do
        result = described_class.call("", color: :red)

        expect(result).to eq("\e[0;31;49m\e[0m")
      end

      it "handles multi-word text" do
        result = described_class.call("Hello World", color: :green, mode: :bold)

        expect(result).to eq("\e[1;32;49mHello World\e[0m")
      end

      it "handles text with special characters" do
        result = described_class.call("Error: 100%", color: :red)

        expect(result).to eq("\e[0;31;49mError: 100%\e[0m")
      end

      it "handles text with newlines" do
        result = described_class.call("Line 1\nLine 2", color: :blue)

        expect(result).to eq("\e[0;34;49mLine 1\nLine 2\e[0m")
      end

      it "handles numeric text" do
        result = described_class.call("12345", color: :cyan)

        expect(result).to eq("\e[0;36;49m12345\e[0m")
      end
    end

    context "with light color variants" do
      it "handles light_red color correctly" do
        result = described_class.call("Bright Red", color: :light_red)

        expect(result).to eq("\e[0;91;49mBright Red\e[0m")
      end

      it "handles light_green color correctly" do
        result = described_class.call("Bright Green", color: :light_green)

        expect(result).to eq("\e[0;92;49mBright Green\e[0m")
      end

      it "handles light_blue color correctly" do
        result = described_class.call("Bright Blue", color: :light_blue)

        expect(result).to eq("\e[0;94;49mBright Blue\e[0m")
      end

      it "handles light_yellow color correctly" do
        result = described_class.call("Bright Yellow", color: :light_yellow)

        expect(result).to eq("\e[0;93;49mBright Yellow\e[0m")
      end

      it "handles light_magenta color correctly" do
        result = described_class.call("Bright Magenta", color: :light_magenta)

        expect(result).to eq("\e[0;95;49mBright Magenta\e[0m")
      end

      it "handles light_cyan color correctly" do
        result = described_class.call("Bright Cyan", color: :light_cyan)

        expect(result).to eq("\e[0;96;49mBright Cyan\e[0m")
      end

      it "handles light_white color correctly" do
        result = described_class.call("Bright White", color: :light_white)

        expect(result).to eq("\e[0;97;49mBright White\e[0m")
      end
    end

    context "error handling" do
      it "raises KeyError for invalid color" do
        expect do
          described_class.call("Text", color: :invalid_color)
        end.to raise_error(KeyError, "key not found: :invalid_color")
      end

      it "raises KeyError for invalid mode" do
        expect do
          described_class.call("Text", color: :red, mode: :invalid_mode)
        end.to raise_error(KeyError, "key not found: :invalid_mode")
      end

      it "raises KeyError for nil color" do
        expect do
          described_class.call("Text", color: nil)
        end.to raise_error(KeyError)
      end

      it "raises KeyError for nil mode" do
        expect do
          described_class.call("Text", color: :red, mode: nil)
        end.to raise_error(KeyError)
      end
    end
  end
end

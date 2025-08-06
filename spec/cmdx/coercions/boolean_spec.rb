# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is truthy" do
      it "coerces string 'true' to true" do
        result = coercion.call("true")

        expect(result).to be(true)
      end

      it "coerces string 'TRUE' to true" do
        result = coercion.call("TRUE")

        expect(result).to be(true)
      end

      it "coerces string 'True' to true" do
        result = coercion.call("True")

        expect(result).to be(true)
      end

      it "coerces string 't' to true" do
        result = coercion.call("t")

        expect(result).to be(true)
      end

      it "coerces string 'T' to true" do
        result = coercion.call("T")

        expect(result).to be(true)
      end

      it "coerces string 'yes' to true" do
        result = coercion.call("yes")

        expect(result).to be(true)
      end

      it "coerces string 'YES' to true" do
        result = coercion.call("YES")

        expect(result).to be(true)
      end

      it "coerces string 'Yes' to true" do
        result = coercion.call("Yes")

        expect(result).to be(true)
      end

      it "coerces string 'y' to true" do
        result = coercion.call("y")

        expect(result).to be(true)
      end

      it "coerces string 'Y' to true" do
        result = coercion.call("Y")

        expect(result).to be(true)
      end

      it "coerces string '1' to true" do
        result = coercion.call("1")

        expect(result).to be(true)
      end

      it "coerces integer 1 to true" do
        result = coercion.call(1)

        expect(result).to be(true)
      end

      it "coerces boolean true to true" do
        result = coercion.call(true)

        expect(result).to be(true)
      end
    end

    context "when value is falsey" do
      it "coerces string 'false' to false" do
        result = coercion.call("false")

        expect(result).to be(false)
      end

      it "coerces string 'FALSE' to false" do
        result = coercion.call("FALSE")

        expect(result).to be(false)
      end

      it "coerces string 'False' to false" do
        result = coercion.call("False")

        expect(result).to be(false)
      end

      it "coerces string 'f' to false" do
        result = coercion.call("f")

        expect(result).to be(false)
      end

      it "coerces string 'F' to false" do
        result = coercion.call("F")

        expect(result).to be(false)
      end

      it "coerces string 'no' to false" do
        result = coercion.call("no")

        expect(result).to be(false)
      end

      it "coerces string 'NO' to false" do
        result = coercion.call("NO")

        expect(result).to be(false)
      end

      it "coerces string 'No' to false" do
        result = coercion.call("No")

        expect(result).to be(false)
      end

      it "coerces string 'n' to false" do
        result = coercion.call("n")

        expect(result).to be(false)
      end

      it "coerces string 'N' to false" do
        result = coercion.call("N")

        expect(result).to be(false)
      end

      it "coerces string '0' to false" do
        result = coercion.call("0")

        expect(result).to be(false)
      end

      it "coerces integer 0 to false" do
        result = coercion.call(0)

        expect(result).to be(false)
      end

      it "coerces boolean false to false" do
        result = coercion.call(false)

        expect(result).to be(false)
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for invalid string" do
        expect { coercion.call("invalid") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for empty string" do
        expect { coercion.call("") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for symbol" do
        expect { coercion.call(:symbol) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(3.14) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for integer 2" do
        expect { coercion.call(2) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for negative integer" do
        expect { coercion.call(-1) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for partial match string" do
        expect { coercion.call("truth") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for string with whitespace" do
        expect { coercion.call(" true ") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end

      it "raises CoercionError for string with mixed case that doesn't match patterns" do
        expect { coercion.call("TrUeX") }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end
    end

    context "with options parameter" do
      it "ignores options parameter for valid truthy value" do
        result = coercion.call("true", { some: "option" })

        expect(result).to be(true)
      end

      it "ignores options parameter for valid falsey value" do
        result = coercion.call("false", { some: "option" })

        expect(result).to be(false)
      end

      it "ignores options parameter for invalid value" do
        expect { coercion.call("invalid", { some: "option" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end
    end
  end
end

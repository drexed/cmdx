# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::NameAffix do
  describe ".call" do
    context "with no prefix or suffix" do
      it "returns the original method name as symbol" do
        result = described_class.call(:method_name, "source")

        expect(result).to eq(:method_name)
      end

      it "converts string method name to symbol" do
        result = described_class.call("method_name", "source")

        expect(result).to eq(:method_name)
      end

      it "handles method names with underscores" do
        result = described_class.call(:user_email, "admin")

        expect(result).to eq(:user_email)
      end

      it "handles single character method names" do
        result = described_class.call(:x, "coord")

        expect(result).to eq(:x)
      end
    end

    context "with prefix option" do
      it "adds source as prefix when prefix is true" do
        result = described_class.call(:method, "user", prefix: true)

        expect(result).to eq(:user_method)
      end

      it "adds custom prefix when prefix is string" do
        result = described_class.call(:email, "admin", prefix: "get_")

        expect(result).to eq(:get_email)
      end

      it "adds custom prefix with special characters" do
        result = described_class.call(:count, "items", prefix: "fetch-")

        expect(result).to eq(:"fetch-count")
      end

      it "handles empty custom prefix" do
        result = described_class.call(:method, "source", prefix: "")

        expect(result).to eq(:method)
      end

      it "handles numeric custom prefix" do
        result = described_class.call(:value, "source", prefix: "123_")

        expect(result).to eq(:"123_value")
      end
    end

    context "with suffix option" do
      it "adds source as suffix when suffix is true" do
        result = described_class.call(:method, "user", suffix: true)

        expect(result).to eq(:method_user)
      end

      it "adds custom suffix when suffix is string" do
        result = described_class.call(:email, "user", suffix: "_count")

        expect(result).to eq(:email_count)
      end

      it "adds question mark suffix" do
        result = described_class.call(:valid, "user", suffix: "?")

        expect(result).to eq(:valid?)
      end

      it "adds exclamation mark suffix" do
        result = described_class.call(:save, "record", suffix: "!")

        expect(result).to eq(:save!)
      end

      it "handles empty custom suffix" do
        result = described_class.call(:method, "source", suffix: "")

        expect(result).to eq(:method)
      end
    end

    context "with both prefix and suffix" do
      it "adds both source prefix and suffix when both are true" do
        result = described_class.call(:name, "user", prefix: true, suffix: true)

        expect(result).to eq(:user_name_user)
      end

      it "adds custom prefix and custom suffix" do
        result = described_class.call(:process, "order", prefix: "can_", suffix: "_now")

        expect(result).to eq(:can_process_now)
      end

      it "combines true prefix with custom suffix" do
        result = described_class.call(:email, "user", prefix: true, suffix: "?")

        expect(result).to eq(:user_email?)
      end

      it "combines custom prefix with true suffix" do
        result = described_class.call(:count, "items", prefix: "get_", suffix: true)

        expect(result).to eq(:get_count_items)
      end

      it "handles complex combinations" do
        result = described_class.call(:method, "api", prefix: "fetch_", suffix: "_data")

        expect(result).to eq(:fetch_method_data)
      end
    end

    context "with as option" do
      it "overrides entire name when as is provided" do
        result = described_class.call(:original, "source", as: :custom_method)

        expect(result).to eq(:custom_method)
      end

      it "ignores prefix when as is provided" do
        result = described_class.call(:original, "source", prefix: true, as: :custom)

        expect(result).to eq(:custom)
      end

      it "ignores suffix when as is provided" do
        result = described_class.call(:original, "source", suffix: true, as: :custom)

        expect(result).to eq(:custom)
      end

      it "ignores both prefix and suffix when as is provided" do
        result = described_class.call(:original, "source", prefix: true, suffix: true, as: :custom)

        expect(result).to eq(:custom)
      end

      it "handles as option with string value" do
        result = described_class.call(:original, "source", as: "custom_method")

        expect(result).to eq("custom_method")
      end
    end

    context "with various method name formats" do
      it "handles camelCase method names" do
        result = described_class.call(:getUserEmail, "admin", prefix: true)

        expect(result).to eq(:admin_getUserEmail)
      end

      it "handles PascalCase method names" do
        result = described_class.call(:ProcessOrder, "payment", suffix: "!")

        expect(result).to eq(:ProcessOrder!)
      end

      it "handles method names with numbers" do
        result = described_class.call(:method2, "version", prefix: "get_")

        expect(result).to eq(:get_method2)
      end

      it "handles acronym method names" do
        result = described_class.call(:API, "rest", suffix: "_client")

        expect(result).to eq(:API_client)
      end

      it "handles very long method names" do
        long_name = :very_long_method_name_that_describes_complex_functionality
        result = described_class.call(long_name, "helper", prefix: "build_")

        expect(result).to eq(:build_very_long_method_name_that_describes_complex_functionality)
      end
    end

    context "with various source formats" do
      it "handles source with underscores" do
        result = described_class.call(:method, "user_account", prefix: true)

        expect(result).to eq(:user_account_method)
      end

      it "handles source with hyphens" do
        result = described_class.call(:method, "admin-panel", suffix: true)

        expect(result).to eq(:"method_admin-panel")
      end

      it "handles numeric source" do
        result = described_class.call(:method, "123", prefix: true)

        expect(result).to eq(:"123_method")
      end

      it "handles single character source" do
        result = described_class.call(:coordinate, "x", suffix: true)

        expect(result).to eq(:coordinate_x)
      end

      it "handles empty source" do
        result = described_class.call(:method, "", prefix: true)

        expect(result).to eq(:_method)
      end
    end

    context "edge cases" do
      it "handles nil method name" do
        result = described_class.call(nil, "source", prefix: true)

        expect(result).to eq(:source_)
      end

      it "handles empty method name" do
        result = described_class.call("", "source", suffix: true)

        expect(result).to eq(:_source)
      end

      it "handles whitespace in method name" do
        result = described_class.call(" method ", "source", prefix: true)

        expect(result).to eq(:"source_ method")
      end

      it "handles special characters in method name" do
        result = described_class.call("method@test", "api", suffix: "!")

        expect(result).to eq(:"method@test!")
      end

      it "strips whitespace correctly" do
        result = described_class.call(:method, "user", prefix: " prefix_", suffix: "_suffix ")

        expect(result).to eq(:prefix_method_suffix)
      end
    end

    context "delegation scenarios" do
      it "creates namespaced method names" do
        result = described_class.call(:count, "users", prefix: true)

        expect(result).to eq(:users_count)
      end

      it "creates accessor method names" do
        result = described_class.call(:name, "user", prefix: "fetch_")

        expect(result).to eq(:fetch_name)
      end

      it "creates action method names" do
        result = described_class.call(:process, "order", suffix: "_async")

        expect(result).to eq(:process_async)
      end

      it "creates callback method names" do
        result = described_class.call(:validate, "user", prefix: "before_")

        expect(result).to eq(:before_validate)
      end

      it "creates utility method names" do
        result = described_class.call(:format, "date", prefix: "helper_", suffix: "_display")

        expect(result).to eq(:helper_format_display)
      end
    end

    context "method generation patterns" do
      it "creates boolean method names" do
        methods = %i[valid empty present authenticated].map do |method|
          described_class.call(method, "user", suffix: "?")
        end

        expect(methods).to eq(%i[valid? empty? present? authenticated?])
      end

      it "creates action method names" do
        methods = %i[save delete update create].map do |method|
          described_class.call(method, "record", suffix: "!")
        end

        expect(methods).to eq(%i[save! delete! update! create!])
      end

      it "creates namespace method names" do
        methods = %i[count find create].map do |method|
          described_class.call(method, "users", prefix: true)
        end

        expect(methods).to eq(%i[users_count users_find users_create])
      end

      it "creates getter method names" do
        methods = %i[name email address phone].map do |method|
          described_class.call(method, "user", prefix: "get_")
        end

        expect(methods).to eq(%i[get_name get_email get_address get_phone])
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Parameters", type: :integration do
  describe "Parameter Definitions and Basic Usage" do
    let(:basic_order_task) do
      Class.new(CMDx::Task) do
        required :order_id, :customer_id
        optional :priority, :notes

        def call
          context.order = {
            id: order_id,
            customer_id: customer_id,
            priority: priority,
            notes: notes
          }
        end
      end
    end

    let(:typed_parameters_task) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        required :amount, type: :float
        required :is_active, type: :boolean
        optional :tags, type: :array, default: []
        optional :metadata, type: :hash, default: {}

        def call
          context.processed_data = {
            user_id: user_id,
            amount: amount,
            is_active: is_active,
            tags: tags,
            metadata: metadata
          }
        end
      end
    end

    context "with basic parameter definitions" do
      it "processes required and optional parameters correctly" do
        result = basic_order_task.call(
          order_id: "ORD-123",
          customer_id: "CUST-456",
          priority: "high",
          notes: "Rush delivery"
        )

        expect(result).to be_successful_task
        expect(result).to have_context(
          order: {
            id: "ORD-123",
            customer_id: "CUST-456",
            priority: "high",
            notes: "Rush delivery"
          }
        )
      end

      it "handles missing optional parameters" do
        result = basic_order_task.call(
          order_id: "ORD-789",
          customer_id: "CUST-101"
        )

        expect(result).to be_successful_task
        expect(result.context.order[:id]).to eq("ORD-789")
        expect(result.context.order[:customer_id]).to eq("CUST-101")
        expect(result.context.order[:priority]).to be_nil
        expect(result.context.order[:notes]).to be_nil
      end

      it "fails when required parameters are missing" do
        result = basic_order_task.call(order_id: "ORD-999")

        expect(result).to be_failed_task
        expect(result).to have_metadata(reason: include("customer_id is a required parameter"))
      end
    end

    context "with typed parameters and coercion" do
      it "automatically coerces parameter types" do
        result = typed_parameters_task.call(
          user_id: "12345",
          amount: "199.99",
          is_active: "true",
          tags: "[\"premium\", \"vip\"]",
          metadata: "{\"source\": \"api\"}"
        )

        expect(result).to be_successful_task
        expect(result).to have_context(
          processed_data: {
            user_id: 12_345,
            amount: 199.99,
            is_active: true,
            tags: %w[premium vip],
            metadata: { "source" => "api" }
          }
        )
      end

      it "applies default values for optional parameters" do
        result = typed_parameters_task.call(
          user_id: 456,
          amount: 299.99,
          is_active: false
        )

        expect(result).to be_successful_task
        expect(result.context.processed_data[:tags]).to eq([])
        expect(result.context.processed_data[:metadata]).to eq({})
      end
    end
  end

  describe "Parameter Validation Patterns" do
    let(:validation_task) do
      Class.new(CMDx::Task) do
        required :email, format: { with: /@/ }
        required :age, type: :integer, numeric: { within: 18..120 }
        required :status, inclusion: { in: %w[active inactive pending] }
        optional :username, presence: true, length: { within: 3..20 }
        optional :bio, length: { max: 500 }

        def call
          context.user_data = {
            email: email,
            age: age,
            status: status,
            username: username,
            bio: bio
          }
        end
      end
    end

    let(:advanced_validation_task) do
      Class.new(CMDx::Task) do
        required :password, format: {
          with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,
          message: "must contain uppercase, lowercase, and digit"
        }
        required :role, exclusion: { in: %w[admin superuser] }
        required :credit_score, numeric: { min: 300, max: 850 }
        optional :phone, format: { with: /\A\d{10}\z/ }

        def call
          context.validated_data = {
            password_valid: true,
            role: role,
            credit_score: credit_score,
            phone: phone
          }
        end
      end
    end

    context "with format validation" do
      it "validates email format successfully" do
        result = validation_task.call(
          email: "user@example.com",
          age: 25,
          status: "active",
          username: "johndoe"
        )

        expect(result).to be_successful_task
        expect(result.context.user_data[:email]).to eq("user@example.com")
      end

      it "fails with invalid email format" do
        result = validation_task.call(
          email: "invalid-email",
          age: 25,
          status: "active"
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("is an invalid format")
      end
    end

    context "with numeric validation" do
      it "validates age within range" do
        result = validation_task.call(
          email: "test@example.com",
          age: 30,
          status: "active"
        )

        expect(result).to be_successful_task
        expect(result.context.user_data[:age]).to eq(30)
      end

      it "fails with age outside range" do
        result = validation_task.call(
          email: "test@example.com",
          age: 150,
          status: "active"
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("age must be within 18 and 120")
      end
    end

    context "with inclusion validation" do
      it "validates status in allowed values" do
        result = validation_task.call(
          email: "test@example.com",
          age: 25,
          status: "pending"
        )

        expect(result).to be_successful_task
        expect(result.context.user_data[:status]).to eq("pending")
      end

      it "fails with status not in allowed values" do
        result = validation_task.call(
          email: "test@example.com",
          age: 25,
          status: "invalid"
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("must be one of:")
      end
    end

    context "with length validation" do
      it "validates username length within range" do
        result = validation_task.call(
          email: "test@example.com",
          age: 25,
          status: "active",
          username: "johndoe"
        )

        expect(result).to be_successful_task
        expect(result.context.user_data[:username]).to eq("johndoe")
      end

      it "fails with username too short" do
        result = validation_task.call(
          email: "test@example.com",
          age: 25,
          status: "active",
          username: "jo"
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("username length must be within 3 and 20")
      end
    end

    context "with advanced validation patterns" do
      it "validates complex password requirements" do
        result = advanced_validation_task.call(
          password: "MyPassword123",
          role: "user",
          credit_score: 750
        )

        expect(result).to be_successful_task
        expect(result.context.validated_data[:password_valid]).to be(true)
      end

      it "fails with weak password" do
        result = advanced_validation_task.call(
          password: "weakpass",
          role: "user",
          credit_score: 750
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("must contain uppercase, lowercase, and digit")
      end

      it "validates exclusion of restricted roles" do
        result = advanced_validation_task.call(
          password: "ValidPass123",
          role: "admin",
          credit_score: 750
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("must not be one of:")
      end
    end
  end

  describe "Parameter Coercion and Type Handling" do
    let(:coercion_task) do
      Class.new(CMDx::Task) do
        required :quantity, type: :integer
        required :price, type: :float
        required :enabled, type: :boolean
        required :order_date, type: :date
        required :created_at, type: :datetime
        optional :item_list, type: :array, default: []
        optional :extra_data, type: :hash, default: {}

        def call
          context.coerced_values = {
            quantity: quantity,
            price: price,
            enabled: enabled,
            order_date: order_date,
            created_at: created_at,
            item_list: item_list,
            extra_data: extra_data
          }
        end
      end
    end

    let(:multi_type_task) do
      Class.new(CMDx::Task) do
        required :amount, type: %i[float integer]
        optional :config, type: %i[hash string]
        optional :timestamp, type: %i[datetime date string]

        def call
          context.multi_type_values = {
            amount: amount,
            config: config,
            timestamp: timestamp
          }
        end
      end
    end

    context "with single type coercion" do
      it "coerces string values to appropriate types" do
        result = coercion_task.call(
          quantity: "42",
          price: "199.99",
          enabled: "true",
          order_date: "2023-12-25",
          created_at: "2023-12-25 14:30:00"
        )

        expect(result).to be_successful_task
        expect(result.context.coerced_values[:quantity]).to eq(42)
        expect(result.context.coerced_values[:price]).to eq(199.99)
        expect(result.context.coerced_values[:enabled]).to be(true)
        expect(result.context.coerced_values[:order_date]).to be_a(Date)
        expect(result.context.coerced_values[:created_at]).to be_a(DateTime)
      end

      it "handles boolean text patterns" do
        [
          ["true", true],
          ["yes", true],
          ["1", true],
          ["false", false],
          ["no", false],
          ["0", false]
        ].each do |input, expected|
          result = coercion_task.call(
            quantity: 1,
            price: 10.0,
            enabled: input,
            order_date: "2023-01-01",
            created_at: "2023-01-01 00:00:00"
          )

          expect(result).to be_successful_task
          expect(result.context.coerced_values[:enabled]).to be(expected)
        end
      end

      it "coerces JSON strings to arrays and hashes" do
        result = coercion_task.call(
          quantity: 1,
          price: 10.0,
          enabled: true,
          order_date: "2023-01-01",
          created_at: "2023-01-01 00:00:00",
          item_list: "[\"item1\", \"item2\", \"item3\"]",
          extra_data: "{\"key\": \"value\", \"count\": 42}"
        )

        expect(result).to be_successful_task
        expect(result.context.coerced_values[:item_list]).to eq(%w[item1 item2 item3])
        expect(result.context.coerced_values[:extra_data]).to eq({ "key" => "value", "count" => 42 })
      end
    end

    context "with multiple type coercion" do
      it "tries types in order until one succeeds" do
        # Float coercion should succeed
        result = multi_type_task.call(amount: "149.99")
        expect(result).to be_successful_task
        expect(result.context.multi_type_values[:amount]).to eq(149.99)

        # Integer coercion should succeed when float fails
        result = multi_type_task.call(amount: "150")
        expect(result).to be_successful_task
        expect(result.context.multi_type_values[:amount]).to eq(150)
      end

      it "handles hash vs string coercion fallback" do
        # Hash coercion should succeed
        result = multi_type_task.call(
          amount: 100,
          config: "{\"setting\": \"value\"}"
        )
        expect(result).to be_successful_task
        expect(result.context.multi_type_values[:config]).to eq({ "setting" => "value" })

        # String coercion should succeed when hash fails
        result = multi_type_task.call(
          amount: 100,
          config: "simple string config"
        )
        expect(result).to be_successful_task
        expect(result.context.multi_type_values[:config]).to eq("simple string config")
      end
    end
  end

  describe "Parameter Defaults and Dynamic Values" do
    let(:defaults_task) do
      Class.new(CMDx::Task) do
        required :order_id
        optional :priority, default: "normal"
        optional :notification_enabled, type: :boolean, default: true
        optional :max_retries, type: :integer, default: 3
        optional :tags, type: :array, default: []
        optional :metadata, type: :hash, default: {}

        def call
          context.order_data = {
            order_id: order_id,
            priority: priority,
            notification_enabled: notification_enabled,
            max_retries: max_retries,
            tags: tags,
            metadata: metadata
          }
        end
      end
    end

    let(:dynamic_defaults_task) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        optional :created_at, type: :datetime, default: -> { Time.now }
        optional :tracking_id, default: -> { SecureRandom.uuid }
        optional :priority, default: :determine_priority
        optional :notification_service, default: -> { "mock" }

        def call
          context.dynamic_data = {
            user_id: user_id,
            created_at: created_at,
            tracking_id: tracking_id,
            priority: priority,
            notification_service: notification_service
          }
        end

        private

        def determine_priority
          user_id < 1000 ? "high" : "normal"
        end
      end
    end

    context "with fixed default values" do
      it "applies defaults for missing optional parameters" do
        result = defaults_task.call(order_id: "ORD-123")

        expect(result).to be_successful_task
        expect(result.context.order_data[:priority]).to eq("normal")
        expect(result.context.order_data[:notification_enabled]).to be(true)
        expect(result.context.order_data[:max_retries]).to eq(3)
        expect(result.context.order_data[:tags]).to eq([])
        expect(result.context.order_data[:metadata]).to eq({})
      end

      it "allows explicit values to override defaults" do
        result = defaults_task.call(
          order_id: "ORD-456",
          priority: "urgent",
          notification_enabled: false,
          max_retries: 5
        )

        expect(result).to be_successful_task
        expect(result.context.order_data[:priority]).to eq("urgent")
        expect(result.context.order_data[:notification_enabled]).to be(false)
        expect(result.context.order_data[:max_retries]).to eq(5)
      end
    end

    context "with dynamic default values" do
      it "evaluates callable defaults at runtime" do
        freeze_time = Time.parse("2023-12-25 10:00:00")
        allow(Time).to receive(:now).and_return(freeze_time)
        allow(SecureRandom).to receive(:uuid).and_return("test-uuid-123")

        result = dynamic_defaults_task.call(user_id: 500)

        expect(result).to be_successful_task
        expect(result.context.dynamic_data[:created_at]).to eq(freeze_time)
        expect(result.context.dynamic_data[:tracking_id]).to eq("test-uuid-123")
        expect(result.context.dynamic_data[:priority]).to eq("high")
        expect(result.context.dynamic_data[:notification_service]).to eq("mock")
      end

      it "evaluates method-based defaults" do
        result = dynamic_defaults_task.call(user_id: 1500)

        expect(result).to be_successful_task
        expect(result.context.dynamic_data[:priority]).to eq("normal")
      end
    end
  end

  describe "Nested Parameters and Complex Structures" do
    let(:nested_address_task) do
      Class.new(CMDx::Task) do
        required :order_id
        required :shipping_address do
          required :street, :city, :state
          required :zip_code, format: { with: /\A\d{5}\z/ }
          optional :apartment
        end
        optional :billing_address do
          required :street, :city
          optional :same_as_shipping, type: :boolean, default: false
        end

        def call
          context.order_details = {
            order_id: order_id,
            shipping: {
              street: shipping_address[:street],
              city: shipping_address[:city],
              state: shipping_address[:state],
              zip_code: shipping_address[:zip_code],
              apartment: shipping_address[:apartment]
            },
            billing: if billing_address
                       {
                         street: billing_address[:street],
                         city: billing_address[:city],
                         same_as_shipping: billing_address[:same_as_shipping] || false
                       }
                     end
          }
        end
      end
    end

    let(:multi_level_nested_task) do
      Class.new(CMDx::Task) do
        required :user do
          required :name, :email
          required :profile do
            required :age, type: :integer
            optional :bio, length: { max: 200 }
            optional :preferences do
              optional :theme, inclusion: { in: %w[light dark] }
              optional :language, default: "en"
              required :notifications, type: :boolean
            end
          end
        end

        def call
          context.user_profile = {
            name: name,
            email: email,
            age: age,
            bio: bio,
            theme: defined?(theme) ? theme : nil,
            language: defined?(language) ? language : nil,
            notifications: defined?(notifications) ? notifications : nil
          }
        end
      end
    end

    context "with nested parameter structures" do
      it "processes required nested parameters" do
        result = nested_address_task.call(
          order_id: "ORD-789",
          shipping_address: {
            street: "123 Main St",
            city: "San Francisco",
            state: "CA",
            zip_code: "94105",
            apartment: "Apt 4B"
          }
        )

        expect(result).to be_successful_task
        expect(result.context.order_details[:shipping][:street]).to eq("123 Main St")
        expect(result.context.order_details[:shipping][:apartment]).to eq("Apt 4B")
      end

      it "validates nested parameter formats" do
        result = nested_address_task.call(
          order_id: "ORD-999",
          shipping_address: {
            street: "456 Oak Ave",
            city: "Portland",
            state: "OR",
            zip_code: "invalid-zip"
          }
        )

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("is an invalid format")
      end

      it "handles optional nested parameters with defaults" do
        result = nested_address_task.call(
          order_id: "ORD-101",
          shipping_address: {
            street: "789 Pine St",
            city: "Seattle",
            state: "WA",
            zip_code: "98101"
          },
          billing_address: {
            street: "Same Street",
            city: "Same City"
          }
        )

        expect(result).to be_successful_task
        expect(result.context.order_details[:billing][:street]).to eq("Same Street")
        expect(result.context.order_details[:billing][:same_as_shipping]).to be(false)
      end
    end

    context "with multi-level nesting" do
      it "processes deeply nested required parameters" do
        result = multi_level_nested_task.call(
          user: {
            name: "John Doe",
            email: "john@example.com",
            profile: {
              age: 30,
              bio: "Software developer",
              preferences: {
                theme: "dark",
                language: "en",
                notifications: true
              }
            }
          }
        )

        expect(result).to be_successful_task
        expect(result.context.user_profile[:name]).to eq("John Doe")
        expect(result.context.user_profile[:age]).to eq(30)
        expect(result.context.user_profile[:theme]).to eq("dark")
        expect(result.context.user_profile[:notifications]).to be(true)
      end

      it "handles missing optional nested parameters" do
        result = multi_level_nested_task.call(
          user: {
            name: "Jane Smith",
            email: "jane@example.com",
            profile: {
              age: 25,
              preferences: {
                notifications: false
              }
            }
          }
        )

        expect(result).to be_successful_task
        expect(result.context.user_profile[:name]).to eq("Jane Smith")
        expect(result.context.user_profile[:age]).to eq(25)
        expect(result.context.user_profile[:bio]).to be_nil
        expect(result.context.user_profile[:language]).to eq("en")
        expect(result.context.user_profile[:notifications]).to be(false)
      end
    end
  end

  describe "Parameter Sources and Custom Delegation" do
    let(:source_delegation_task) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        required :name, :email, source: :user
        required :account_type, source: :account
        optional :last_login, source: :user, type: :datetime

        def call
          context.user_data = {
            user_id: user_id,
            name: name,
            email: email,
            account_type: account_type,
            last_login: last_login
          }
        end

        private

        def user
          @user ||= OpenStruct.new(
            name: "User #{context.user_id}",
            email: "user#{context.user_id}@example.com",
            last_login: Time.parse("2023-12-20 09:00:00")
          )
        end

        def account
          @account ||= OpenStruct.new(
            account_type: context.user_id < 100 ? "premium" : "standard"
          )
        end
      end
    end

    let(:dynamic_source_task) do
      Class.new(CMDx::Task) do
        required :order_id, type: :integer
        required :total_amount, source: :order
        required :customer_name, source: :customer
        required :shipping_method, source: :shipping_service

        def call
          context.order_summary = {
            order_id: order_id,
            total_amount: total_amount,
            customer_name: customer_name,
            shipping_method: shipping_method
          }
        end

        private

        def order
          @order ||= OpenStruct.new(
            total_amount: order_id * 10.0
          )
        end

        def customer
          @customer ||= OpenStruct.new(
            customer_name: "Customer #{order_id}"
          )
        end

        def shipping_service
          @shipping_service ||= OpenStruct.new(
            shipping_method: calculate_shipping_method
          )
        end

        def calculate_shipping_method
          order_id > 100 ? "express" : "standard"
        end
      end
    end

    context "with custom parameter sources" do
      it "delegates parameter access to specified sources" do
        result = source_delegation_task.call(user_id: 42)

        expect(result).to be_successful_task
        expect(result.context.user_data[:user_id]).to eq(42)
        expect(result.context.user_data[:name]).to eq("User 42")
        expect(result.context.user_data[:email]).to eq("user42@example.com")
        expect(result.context.user_data[:account_type]).to eq("premium")
        expect(result.context.user_data[:last_login]).to be_a(Time)
      end

      it "handles different source types for different users" do
        result = source_delegation_task.call(user_id: 150)

        expect(result).to be_successful_task
        expect(result.context.user_data[:account_type]).to eq("standard")
      end
    end

    context "with dynamic source resolution" do
      it "resolves parameters from lambda and method sources" do
        result = dynamic_source_task.call(order_id: 75)

        expect(result).to be_successful_task
        expect(result.context.order_summary[:total_amount]).to eq(750.0)
        expect(result.context.order_summary[:customer_name]).to eq("Customer 75")
        expect(result.context.order_summary[:shipping_method]).to eq("standard")
      end

      it "handles conditional logic in source methods" do
        result = dynamic_source_task.call(order_id: 150)

        expect(result).to be_successful_task
        expect(result.context.order_summary[:shipping_method]).to eq("express")
      end
    end
  end

  describe "Parameter Namespacing and Conflict Resolution" do
    let(:namespaced_parameters_task) do
      Class.new(CMDx::Task) do
        required :name, source: :customer, prefix: "customer_"
        required :email, source: :customer, prefix: "customer_"
        required :name, source: :company, prefix: "company_"
        required :email, source: :company, prefix: "company_"
        required :status, source: :order, suffix: "_status"
        required :total, source: :order, suffix: "_amount"

        def call
          context.invoice_data = {
            customer_name: customer_name,
            customer_email: customer_email,
            company_name: company_name,
            company_email: company_email,
            order_status: status_status,
            order_total: total_amount
          }
        end

        private

        def customer
          @customer ||= OpenStruct.new(
            name: "John Customer",
            email: "john@customer.com"
          )
        end

        def company
          @company ||= OpenStruct.new(
            name: "ACME Corp",
            email: "billing@acme.com"
          )
        end

        def order
          @order ||= OpenStruct.new(
            status: "completed",
            total: 1299.99
          )
        end
      end
    end

    let(:automatic_namespacing_task) do
      Class.new(CMDx::Task) do
        required :user_id, prefix: true
        required :profile_data, source: :profile, suffix: true
        required :account_settings, source: :account, prefix: true, suffix: true

        def call
          context.namespaced_data = {
            context_user_id: context_user_id,
            profile_data_profile: profile_data_profile,
            account_account_settings_account: account_account_settings_account
          }
        end

        private

        def profile
          @profile ||= OpenStruct.new(
            profile_data: { theme: "dark", language: "en" }
          )
        end

        def account
          @account ||= OpenStruct.new(
            account_settings: { notifications: true, privacy: "private" }
          )
        end
      end
    end

    context "with fixed prefix and suffix namespacing" do
      it "resolves parameter name conflicts through namespacing" do
        result = namespaced_parameters_task.call

        expect(result).to be_successful_task
        expect(result.context.invoice_data[:customer_name]).to eq("John Customer")
        expect(result.context.invoice_data[:customer_email]).to eq("john@customer.com")
        expect(result.context.invoice_data[:company_name]).to eq("ACME Corp")
        expect(result.context.invoice_data[:company_email]).to eq("billing@acme.com")
        expect(result.context.invoice_data[:order_status]).to eq("completed")
        expect(result.context.invoice_data[:order_total]).to eq(1299.99)
      end
    end

    context "with automatic source-based namespacing" do
      it "generates method names based on source names" do
        result = automatic_namespacing_task.call(user_id: 123)

        expect(result).to be_successful_task
        expect(result.context.namespaced_data[:context_user_id]).to eq(123)
        expect(result.context.namespaced_data[:profile_data_profile]).to eq({ theme: "dark", language: "en" })
        expect(result.context.namespaced_data[:account_account_settings_account]).to eq({ notifications: true, privacy: "private" })
      end
    end
  end

  describe "Parameter Error Handling and Validation Messages" do
    let(:comprehensive_validation_task) do
      Class.new(CMDx::Task) do
        required :email, format: { with: /@/, message: "must be a valid email address" }
        required :age, type: :integer, numeric: { within: 18..65, message: "must be between 18 and 65" }
        required :role, inclusion: { in: %w[user admin], message: "must be user or admin" }
        optional :password, presence: { message: "cannot be blank if provided" }
        optional :bio, length: { max: 100, message: "must be 100 characters or less" }

        def call
          context.validation_passed = true
        end
      end
    end

    context "with comprehensive validation error messages" do
      it "provides detailed error information for multiple validation failures" do
        result = comprehensive_validation_task.call(
          email: "invalid-email",
          age: 150,
          role: "superuser",
          password: "",
          bio: "A" * 150
        )

        expect(result).to be_failed_task
        expect(result.metadata[:messages]).to be_a(Hash)
        expect(result.metadata[:messages][:email]).to include("must be a valid email address")
        expect(result.metadata[:messages][:age]).to include("must be between 18 and 65")
        expect(result.metadata[:messages][:role]).to include("must be user or admin")
        expect(result.metadata[:messages][:password]).to include("cannot be blank if provided")
        expect(result.metadata[:messages][:bio]).to include("must be 100 characters or less")
      end

      it "succeeds with all valid parameters" do
        result = comprehensive_validation_task.call(
          email: "user@example.com",
          age: 30,
          role: "user",
          password: "securepass123",
          bio: "A short bio"
        )

        expect(result).to be_successful_task
        expect(result.context.validation_passed).to be(true)
      end
    end
  end
end

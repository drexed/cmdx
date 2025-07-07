# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task Internationalization", type: :integration do
  let(:simple_task_class) do
    Class.new(CMDx::Task) do
      def self.name
        "SimpleInternationalizationTask"
      end

      required :user_id, type: :integer
      required :email, format: { with: /@/ }
      required :age, numeric: { min: 18 }
      required :status, inclusion: { in: %w[active inactive] }
      required :name, presence: true

      def call
        # Task implementation
      end
    end
  end

  after do
    I18n.locale = I18n.default_locale
  end

  describe "English Locale" do
    before { I18n.locale = :en }

    it "uses English coercion error messages" do
      result = simple_task_class.call(
        user_id: "invalid",
        email: "test@example.com",
        age: 25,
        status: "active",
        name: "John"
      )

      expect(result).to be_failed_task
      expect(result.metadata[:messages][:user_id]).to include("could not coerce into an integer")
    end

    it "uses English validation error messages" do
      result = simple_task_class.call(
        user_id: 123,
        email: "invalid-email",
        age: 16,
        status: "unknown",
        name: ""
      )

      expect(result).to be_failed_task
      expect(result.metadata[:messages][:email]).to include("is an invalid format")
      expect(result.metadata[:messages][:age]).to include("must be at least 18")
      expect(result.metadata[:messages][:status]).to include("must be one of: \"active\", \"inactive\"")
      expect(result.metadata[:messages][:name]).to include("cannot be empty")
    end
  end

  describe "Spanish Locale" do
    before { I18n.locale = :es }

    it "uses Spanish coercion error messages" do
      result = simple_task_class.call(
        user_id: "invalid",
        email: "test@example.com",
        age: 25,
        status: "active",
        name: "Juan"
      )

      expect(result).to be_failed_task
      expect(result.metadata[:messages][:user_id]).to include("no podía coacciona el valor a un integer")
    end

    it "uses Spanish validation error messages" do
      result = simple_task_class.call(
        user_id: 123,
        email: "invalid-email",
        age: 16,
        status: "unknown",
        name: ""
      )

      expect(result).to be_failed_task
      expect(result.metadata[:messages][:email]).to include("es un formato inválido")
      expect(result.metadata[:messages][:age]).to include("debe ser 18 como minimo")
      expect(result.metadata[:messages][:status]).to include("debe ser uno de: \"active\", \"inactive\"")
      expect(result.metadata[:messages][:name]).to include("no puede estar vacío")
    end
  end

  describe "Locale switching" do
    it "changes error messages when locale is switched" do
      # Start with English
      I18n.locale = :en
      result_en = simple_task_class.call(
        user_id: "invalid",
        email: "test@example.com",
        age: 25,
        status: "active",
        name: "Test"
      )

      # Switch to Spanish
      I18n.locale = :es
      result_es = simple_task_class.call(
        user_id: "invalid",
        email: "test@example.com",
        age: 25,
        status: "active",
        name: "Test"
      )

      expect(result_en).to be_failed_task
      expect(result_es).to be_failed_task

      # Verify messages are different
      expect(result_en.metadata[:messages][:user_id]).to include("could not coerce into an integer")
      expect(result_es.metadata[:messages][:user_id]).to include("no podía coacciona el valor a un integer")
    end
  end
end

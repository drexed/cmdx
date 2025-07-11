# frozen_string_literal: true

# RSpec matcher for asserting that a task class has a specific parameter.
#
# This matcher checks if a CMDx::Task class has registered a parameter with the
# specified name. Parameters are inputs to task execution that can be required
# or optional, typed with coercions, validated, and have default values. The
# matcher supports various chain methods for precise parameter validation.
#
# @param parameter_name [Symbol, String] the name of the parameter to check for
#
# @return [Boolean] true if the task has the specified parameter and optionally matches all criteria
#
# @example Testing basic parameter presence
#   class MyTask < CMDx::Task
#     optional :input_file, type: :string
#     def call; end
#   end
#   expect(MyTask).to have_parameter(:input_file)
#
# @example Testing required parameter
#   class ProcessTask < CMDx::Task
#     required data, type: :string
#     def call; end
#   end
#   expect(ProcessTask).to have_parameter(:data).that_is_required
#
# @example Testing optional parameter with default
#   class ConfigTask < CMDx::Task
#     optional timeout, type: :integer, default: 30
#     def call; end
#   end
#   expect(ConfigTask).to have_parameter(:timeout).that_is_optional.with_default(30)
#
# @example Testing parameter with type coercion
#   class ImportTask < CMDx::Task
#     optional csv_file, type: :string
#     optional batch_size, type: :integer
#     def call; end
#   end
#   expect(ImportTask).to have_parameter(:csv_file).with_type(:string)
#   expect(ImportTask).to have_parameter(:batch_size).with_coercion(:integer)
#
# @example Testing parameter with validations
#   class UserTask < CMDx::Task
#     optional email, type: :string, format: /@/, presence: true
#     def call; end
#   end
#   expect(UserTask).to have_parameter(:email).with_validations(:format, :presence)
#
# @example Negative assertion
#   class SimpleTask < CMDx::Task
#     def call; end
#   end
#   expect(SimpleTask).not_to have_parameter(:nonexistent)
RSpec::Matchers.define :have_parameter do |parameter_name|
  match do |task_class|
    @parameter = task_class.cmd_parameters.registry.find { |p| p.method_name == parameter_name }
    return false unless @parameter

    # Check if parameter exists
    parameter_exists = !@parameter.nil?
    return false unless parameter_exists

    # Check required/optional if specified
    unless @expected_required.nil?
      required_matches = @parameter.required? == @expected_required
      return false unless required_matches
    end

    # Check type/coercion if specified
    if @expected_type
      type_matches = @parameter.type == @expected_type
      return false unless type_matches
    end

    # Check validations if specified
    if @expected_validations&.any?
      validations_match = @expected_validations.all? do |validation_type|
        @parameter.options.key?(validation_type)
      end
      return false unless validations_match
    end

    # Check default value if specified
    if @expected_default_value != :__not_specified__
      default_matches = @parameter.options[:default] == @expected_default_value
      return false unless default_matches
    end

    true
  end

  chain :that_is_required do
    @expected_required = true
  end

  chain :that_is_optional do
    @expected_required = false
  end

  chain :with_type do |type|
    @expected_type = type
  end

  chain :with_coercion do |type|
    @expected_type = type
  end

  chain :with_validations do |*validations|
    @expected_validations = validations
  end

  chain :with_validation do |validation|
    @expected_validations = [@expected_validations, validation].flatten.compact
  end

  chain :with_default do |default_value|
    @expected_default_value = default_value
  end

  define_method :initialize do |parameter_name|
    @parameter_name = parameter_name
    @expected_required = nil
    @expected_type = nil
    @expected_validations = []
    @expected_default_value = :__not_specified__
  end

  failure_message do |task_class|
    if @parameter.nil?
      available_parameters = task_class.cmd_parameters.registry.map(&:method_name)
      "expected task to have parameter #{@parameter_name}, but had parameters: #{available_parameters}"
    else
      issues = []

      if !@expected_required.nil? && @parameter.required? != @expected_required
        expected_req_text = @expected_required ? "required" : "optional"
        actual_req_text = @parameter.required? ? "required" : "optional"
        issues << "expected parameter to be #{expected_req_text}, but was #{actual_req_text}"
      end

      if @expected_type
        actual_type = @parameter.type
        issues << "expected parameter type to be #{@expected_type}, but was #{actual_type}" unless actual_type == @expected_type
      end

      if @expected_validations&.any?
        missing_validations = @expected_validations.reject do |validation_type|
          @parameter.options.key?(validation_type)
        end

        if missing_validations.any?
          actual_validations = @parameter.options.keys
          issues << "expected parameter to have validations #{missing_validations}, but had #{actual_validations}"
        end
      end

      issues << "expected parameter default to be #{@expected_default_value}, but was #{@parameter.options[:default]}" if (@expected_default_value != :__not_specified__) && @parameter.options[:default] != @expected_default_value

      if issues.any?
        "expected parameter #{@parameter_name} to match criteria, but #{issues.join(', ')}"
      else
        "expected parameter #{@parameter_name} to match all criteria, but something didn't match"
      end
    end
  end

  failure_message_when_negated do |_task_class|
    "expected task not to have parameter #{@parameter_name}, but it did"
  end

  description do
    desc = "have parameter #{@parameter_name}"
    desc += " that is #{@expected_required ? 'required' : 'optional'}" unless @expected_required.nil?
    desc += " with type #{@expected_type}" if @expected_type
    desc += " with validations #{@expected_validations}" if @expected_validations&.any?
    desc += " with default #{@expected_default_value}" if @expected_default_value != :__not_specified__
    desc
  end
end

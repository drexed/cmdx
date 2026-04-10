# frozen_string_literal: true

module CMDx
  # Centralized registry of all error/validation message templates.
  # English-only in core; i18n is opt-in via `CMDx.message_resolver`.
  module Messages

    TEMPLATES = {
      "coercion.single" => "could not coerce into %<type>s",
      "coercion.multi" => "could not coerce into one of: %<types>s",

      "attribute.required" => "is required",
      "attribute.reserved" => "conflicts with a reserved method name",

      "validation.presence" => "can't be blank",
      "validation.absence" => "must be blank",
      "validation.format" => "is invalid",
      "validation.inclusion.in" => "is not included in the list",
      "validation.inclusion.within" => "is not included in the range %<range>s",
      "validation.exclusion.in" => "is reserved",
      "validation.exclusion.within" => "is within the restricted range %<range>s",
      "validation.length.min" => "is too short (minimum is %<count>s characters)",
      "validation.length.max" => "is too long (maximum is %<count>s characters)",
      "validation.length.is" => "is the wrong length (should be %<count>s characters)",
      "validation.length.is_not" => "must not be %<count>s characters",
      "validation.length.within" => "length is not within range %<range>s",
      "validation.length.not_within" => "length must not be within range %<range>s",
      "validation.numeric.min" => "must be greater than or equal to %<count>s",
      "validation.numeric.max" => "must be less than or equal to %<count>s",
      "validation.numeric.is" => "must be equal to %<count>s",
      "validation.numeric.is_not" => "must not be equal to %<count>s",
      "validation.numeric.within" => "is not within range %<range>s",
      "validation.numeric.not_within" => "must not be within range %<range>s",

      "return.missing" => "must be set in the context",

      "halt.unspecified" => "Unspecified",
      "halt.invalid" => "Invalid",

      "deprecation.prohibited" => "%<task>s usage prohibited",
      "deprecation.warning" => "DEPRECATED: %<task>s - migrate to replacement or discontinue use",

      "task.undefined_work" => "%<task>s must define a `work` method",
      "task.workflow_work_defined" => "%<task>s must not define a `work` method when using Workflow",

      "middleware.no_yield" => "Middleware failed to yield execution",

      "timeout.exceeded" => "execution exceeded %<seconds>s seconds"
    }.freeze

    # Resolve a message template with optional interpolations.
    #
    # @param key [String] the message key
    # @param interpolations [Hash] values to interpolate into the template
    # @return [String]
    def self.resolve(key, **interpolations)
      resolver = CMDx.message_resolver
      return resolver.call(key, **interpolations) if resolver

      template = TEMPLATES.fetch(key, key)
      return template if interpolations.empty?

      format(template, **interpolations)
    end

  end
end

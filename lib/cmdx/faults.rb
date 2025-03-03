# frozen_string_literal: true

module CMDx

  # Raised when halting task processing with skipped context
  Skipped = Class.new(Fault)

  # Raised when halting task processing with failed context
  Failed = Class.new(Fault)

end

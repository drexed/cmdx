# frozen_string_literal: true

module RubyVersionHelpers

  module_function

  def atleast?(version)
    puts "~~~"
    pp [Gem::Version.new(RUBY_VERSION), Gem::Version.new(version.to_s)]
    puts
    Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(version.to_s)
  end

  def atmost?(version)
    Gem::Version.new(version.to_s) <= Gem::Version.new(RUBY_VERSION)
  end

end

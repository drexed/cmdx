# frozen_string_literal: true

require_relative "lib/cmdx/version"

Gem::Specification.new do |spec|
  spec.name = "cmdx"
  spec.version = CMDx::VERSION
  spec.authors = ["Juan Gomez"]
  spec.email = ["drexed@users.noreply.github.com"]

  spec.summary = "Command (aka service) objects with intent"
  spec.description = "Simplify complex business logic using a tiny command (service) object framework."
  spec.homepage = "https://github.com/drexed/cmdx"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/drexed/cmdx"
  spec.metadata["changelog_uri"] = "https://github.com/drexed/cmdx/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/drexed/cmdx/issues"
  spec.metadata["documentation_uri"] = "https://github.com/drexed/cmdx/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal"
  spec.add_dependency "logger"
  spec.add_dependency "zeitwerk"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "i18n"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
end

# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Generate YARD API documentation"
task :yard do
  require "yard"
  YARD::CLI::Yardoc.run(*File.readlines(".yardopts", chomp: true).reject(&:empty?))
end

task default: %i[spec rubocop]

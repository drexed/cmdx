#!/usr/bin/env ruby
# frozen_string_literal: true

# Orchestrator — sets up git worktrees for v1 and v2, runs the harness in
# isolated subprocesses, then invokes the report.
#
# USAGE:
#   ruby benchmark/compare.rb
#   RUBY_YJIT_ENABLE=1 ruby benchmark/compare.rb   # include YJIT comparison

require "fileutils"

REPO_ROOT   = File.expand_path("..", __dir__)
BENCH_DIR   = __dir__
TMP_DIR     = File.join(REPO_ROOT, "tmp", "benchmark")
HARNESS     = File.join(BENCH_DIR, "harness.rb")
REPORT      = File.join(BENCH_DIR, "report.rb")
GEMFILE     = File.join(BENCH_DIR, "Gemfile")

VERSIONS = {
  "v1" => "e20d7aa4",
  "v2" => "TODO"
}.freeze

FileUtils.mkdir_p(TMP_DIR)

# ---------------------------------------------------------------------------
# Worktree management
# ---------------------------------------------------------------------------
def setup_worktree(label, sha)
  wt_path = File.join(TMP_DIR, label)

  if Dir.exist?(wt_path)
    puts "Worktree #{label} already exists at #{wt_path}, resetting..."
    system("git", "-C", wt_path, "checkout", "--force", sha, exception: true)
  else
    puts "Creating worktree #{label} at #{sha}..."
    system("git", "-C", REPO_ROOT, "worktree", "add", "--detach", wt_path, sha, exception: true)
  end

  wt_path
end

def cleanup_worktrees
  VERSIONS.each_key do |label|
    wt_path = File.join(TMP_DIR, label)
    next unless Dir.exist?(wt_path)

    puts "Removing worktree #{label}..."
    system("git", "-C", REPO_ROOT, "worktree", "remove", "--force", wt_path)
  end
end

# ---------------------------------------------------------------------------
# Run harness in subprocess
# ---------------------------------------------------------------------------
def run_harness(label, wt_path)
  output_file = File.join(TMP_DIR, "#{label}.json")

  env = {
    "BUNDLE_GEMFILE" => GEMFILE,
    "BUNDLER_ORIG_BUNDLE_GEMFILE" => nil
  }

  cmd = [
    RbConfig.ruby, "-rbundler/setup",
    HARNESS,
    "--root", wt_path,
    "--version", label,
    "--output", output_file
  ]

  puts "\n#{'=' * 60}"
  puts "Running benchmark for #{label} (#{VERSIONS[label]})"
  puts("=" * 60)

  success = system(env, *cmd)
  unless success
    warn "ERROR: Harness failed for #{label}"
    exit 1
  end

  output_file
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
at_exit do
  puts "\nCleaning up worktrees..."
  cleanup_worktrees
end

worktrees = {}
VERSIONS.each do |label, sha|
  worktrees[label] = setup_worktree(label, sha)
end

output_files = {}
VERSIONS.each_key do |label|
  output_files[label] = run_harness(label, worktrees[label])
end

puts "\n#{'=' * 60}"
puts "Generating comparison report..."
puts "#{'=' * 60}\n\n"

system(
  RbConfig.ruby, REPORT,
  "--v1", output_files["v1"],
  "--v2", output_files["v2"]
)

#!/usr/bin/env ruby
# frozen_string_literal: true

# Report generator — reads JSON output from two harness runs and prints
# a side-by-side comparison with deltas and percentage changes.
#
# USAGE (called by compare.rb, or standalone):
#   ruby benchmark/report.rb --v1 tmp/benchmark/v1.json --v2 tmp/benchmark/v2.json

require "optparse"
require "json"

options = {}
OptionParser.new do |opts|
  opts.on("--v1 PATH", "Path to v1 JSON results") { |v| options[:v1] = v }
  opts.on("--v2 PATH", "Path to v2 JSON results") { |v| options[:v2] = v }
end.parse!

v1_data = JSON.parse(File.read(options.fetch(:v1)), symbolize_names: true)
v2_data = JSON.parse(File.read(options.fetch(:v2)), symbolize_names: true)

# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
GREEN  = "\e[32m"
RED    = "\e[31m"
YELLOW = "\e[33m"
CYAN   = "\e[36m"
BOLD   = "\e[1m"
DIM    = "\e[2m"
RESET  = "\e[0m"

def green(s)  = "#{GREEN}#{s}#{RESET}"
def red(s)    = "#{RED}#{s}#{RESET}"
def yellow(s) = "#{YELLOW}#{s}#{RESET}"
def cyan(s)   = "#{CYAN}#{s}#{RESET}"
def bold(s)   = "#{BOLD}#{s}#{RESET}"
def dim(s)    = "#{DIM}#{s}#{RESET}"

# Positive delta = v2 is faster/better; negative = v2 is worse
def colorize_delta(pct, higher_is_better: true)
  better = higher_is_better ? pct.positive? : pct.negative?
  str = format("%+.1f%%", pct)
  if better
    green(str)
  else
    (pct.zero? ? yellow(str) : red(str))
  end
end

def format_number(n)
  return n.to_s if n.is_a?(String)

  n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def section_header(title)
  puts "\n#{bold(cyan('━' * 70))}"
  puts bold(cyan("  #{title}"))
  puts bold(cyan("━" * 70))
end

def table_header(*cols, widths:)
  fmt = widths.map { |w| "%-#{w}s" }.join("  ")
  puts bold(format(fmt, *cols))
  puts dim("─" * (widths.sum + (2 * (widths.size - 1))))
end

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
puts bold("\n#{cyan('╔' + ('═' * 68) + '╗')}")
puts bold(cyan("║  CMDx Benchmark Comparison: v1 vs v2#{' ' * 31}║"))
puts bold(cyan("╚#{'═' * 68}╝"))
puts
puts "  v1: CMDx #{v1_data[:cmdx_version]} (#{dim(v1_data[:version])})"
puts "  v2: CMDx #{v2_data[:cmdx_version]} (#{dim(v2_data[:version])})"
puts "  Ruby: #{v1_data[:ruby]}  |  YJIT: #{v1_data[:yjit] ? green('enabled') : yellow('disabled')}"
puts "  Timestamp: #{v2_data[:timestamp]}"

# ---------------------------------------------------------------------------
# IPS comparison tables
# ---------------------------------------------------------------------------
def print_ips_table(title, v1_suite, v2_suite)
  return unless v1_suite && v2_suite

  section_header("IPS: #{title}")
  widths = [28, 14, 14, 10]
  table_header("Benchmark", "v1 (i/s)", "v2 (i/s)", "Delta", widths: widths)

  v1_suite.each do |label, v1_entry|
    label_s = label.to_s
    v2_entry = v2_suite[label]
    next unless v2_entry

    v1_ips = v1_entry[:ips]
    v2_ips = v2_entry[:ips]
    delta = v1_ips.positive? ? ((v2_ips - v1_ips).to_f / v1_ips * 100) : 0

    printf "%-28s  %14s  %14s  %s\n",
      label_s,
      format_number(v1_ips),
      format_number(v2_ips),
      colorize_delta(delta, higher_is_better: true)
  end
end

v1s = v1_data[:suites]
v2s = v2_data[:suites]

print_ips_table("Task Execution", v1s[:ips_tasks], v2s[:ips_tasks])
print_ips_table("Workflow Execution", v1s[:ips_workflows], v2s[:ips_workflows])
print_ips_table("Context Construction", v1s[:ips_context], v2s[:ips_context])
print_ips_table("Context Access", v1s[:ips_context_access], v2s[:ips_context_access])

# ---------------------------------------------------------------------------
# Memory profiling
# ---------------------------------------------------------------------------
if v1s[:memory] && v2s[:memory]
  section_header("Memory Profiling (per single execution)")

  widths = [22, 14, 14, 10]
  table_header("Scenario", "v1 alloc", "v2 alloc", "Delta", widths: widths)

  v1_mem = v1s[:memory].to_h { |m| [m[:label], m] }
  v2_mem = v2s[:memory].to_h { |m| [m[:label], m] }

  v1_mem.each do |label, v1_entry|
    v2_entry = v2_mem[label]
    next unless v2_entry

    v1_bytes = v1_entry[:total_allocated_memsize]
    v2_bytes = v2_entry[:total_allocated_memsize]
    delta = v1_bytes.positive? ? ((v2_bytes - v1_bytes).to_f / v1_bytes * 100) : 0

    printf "%-22s  %14s  %14s  %s\n",
      label,
      "#{format_number(v1_bytes)} B",
      "#{format_number(v2_bytes)} B",
      colorize_delta(delta, higher_is_better: false)
  end

  puts
  table_header("Scenario", "v1 objects", "v2 objects", "Delta", widths: widths)

  v1_mem.each do |label, v1_entry|
    v2_entry = v2_mem[label]
    next unless v2_entry

    v1_obj = v1_entry[:total_allocated_objects]
    v2_obj = v2_entry[:total_allocated_objects]
    delta = v1_obj.positive? ? ((v2_obj - v1_obj).to_f / v1_obj * 100) : 0

    printf "%-22s  %14s  %14s  %s\n",
      label,
      format_number(v1_obj),
      format_number(v2_obj),
      colorize_delta(delta, higher_is_better: false)
  end

  puts
  table_header("Scenario", "v1 retained", "v2 retained", "Delta", widths: widths)

  v1_mem.each do |label, v1_entry|
    v2_entry = v2_mem[label]
    next unless v2_entry

    v1_ret = v1_entry[:total_retained_memsize]
    v2_ret = v2_entry[:total_retained_memsize]
    delta = v1_ret.positive? ? ((v2_ret - v1_ret).to_f / v1_ret * 100) : 0

    printf "%-22s  %14s  %14s  %s\n",
      label,
      "#{format_number(v1_ret)} B",
      "#{format_number(v2_ret)} B",
      colorize_delta(delta, higher_is_better: false)
  end
end

# ---------------------------------------------------------------------------
# Object Allocations
# ---------------------------------------------------------------------------
if v1s[:allocations] && v2s[:allocations]
  section_header("Object Allocations (top classes per scenario)")

  v1_allocs = v1s[:allocations].to_h { |a| [a[:label], a[:allocations]] }
  v2_allocs = v2s[:allocations].to_h { |a| [a[:label], a[:allocations]] }

  v1_allocs.each do |label, v1_classes|
    v2_classes = v2_allocs[label] || {}
    all_classes = (v1_classes.keys + v2_classes.keys).uniq.first(12)

    puts "\n  #{bold(label)}:"
    widths = [30, 10, 10, 10]
    printf "  %-30s  %10s  %10s  %s\n", bold("Class"), bold("v1"), bold("v2"), bold("Delta")
    puts "  #{dim('─' * 66)}"

    all_classes.each do |klass|
      v1_count = (v1_classes[klass.to_s] || v1_classes[klass.to_sym] || 0).to_i
      v2_count = (v2_classes[klass.to_s] || v2_classes[klass.to_sym] || 0).to_i
      delta = v1_count.positive? ? ((v2_count - v1_count).to_f / v1_count * 100) : 0

      printf "  %-30s  %10s  %10s  %s\n",
        klass.to_s,
        format_number(v1_count),
        format_number(v2_count),
        colorize_delta(delta, higher_is_better: false)
    end
  end
end

# ---------------------------------------------------------------------------
# RSS
# ---------------------------------------------------------------------------
if v1s[:rss] && v2s[:rss]
  section_header("RSS (Resident Set Size) — #{v1s[:rss][:iterations]} iterations each")

  widths = [28, 12, 12, 10]
  table_header("Metric", "v1 (MB)", "v2 (MB)", "Delta", widths: widths)

  [
    ["Before", :before_mb],
    ["After tasks", :after_tasks_mb],
    ["After workflows", :after_workflows_mb],
    ["Task growth", :task_growth_mb],
    ["Workflow growth", :workflow_growth_mb]
  ].each do |label, key|
    v1_val = v1s[:rss][key]
    v2_val = v2s[:rss][key]
    delta = v1_val.to_f.positive? ? ((v2_val - v1_val).to_f / v1_val * 100) : 0

    printf "%-28s  %12.2f  %12.2f  %s\n",
      label, v1_val.to_f, v2_val.to_f,
      colorize_delta(delta, higher_is_better: false)
  end
end

# ---------------------------------------------------------------------------
# GC Stats
# ---------------------------------------------------------------------------
if v1s[:gc_stats] && v2s[:gc_stats]
  section_header("GC Stats — #{v1s[:gc_stats][:iterations]} iterations each")

  widths = [28, 14, 14, 10]

  %i[after_tasks after_workflows].each do |phase|
    label = phase == :after_tasks ? "After Task Execution" : "After Workflow Execution"
    puts "\n  #{bold(label)}:"
    table_header("Metric", "v1", "v2", "Delta", widths: widths)

    v1_gc = v1s[:gc_stats][phase] || {}
    v2_gc = v2s[:gc_stats][phase] || {}

    (v1_gc.keys | v2_gc.keys).each do |metric|
      v1_val = (v1_gc[metric] || v1_gc[metric.to_s] || 0).to_i
      v2_val = (v2_gc[metric] || v2_gc[metric.to_s] || 0).to_i
      delta = v1_val.positive? ? ((v2_val - v1_val).to_f / v1_val * 100) : 0

      printf "%-28s  %14s  %14s  %s\n",
        metric.to_s,
        format_number(v1_val),
        format_number(v2_val),
        colorize_delta(delta, higher_is_better: false)
    end
  end
end

# ---------------------------------------------------------------------------
# YJIT
# ---------------------------------------------------------------------------
if v1s[:yjit] && v2s[:yjit] && !v1s[:yjit][:error] && !v2s[:yjit][:error]
  section_header("YJIT Speedup (with YJIT / without YJIT)")

  v1_yjit = v1s[:yjit]
  v2_yjit = v2s[:yjit]

  if v1_yjit[:speedup] && v2_yjit[:speedup]
    widths = [28, 12, 12]
    table_header("Benchmark", "v1 speedup", "v2 speedup", widths: widths)

    v1_yjit[:speedup].each do |label, v1_ratio|
      v2_ratio = v2_yjit[:speedup][label] || v2_yjit[:speedup][label.to_s]
      next unless v2_ratio

      v1_str = format("%.2fx", v1_ratio)
      v2_str = format("%.2fx", v2_ratio)

      printf "%-28s  %12s  %12s\n", label.to_s, v1_str, v2_str
    end
  elsif v1_yjit[:with_yjit] && v2_yjit[:with_yjit]
    puts "\n  YJIT was enabled at process start; showing YJIT-on IPS only:"
    widths = [28, 14, 14, 10]
    table_header("Benchmark", "v1 (i/s)", "v2 (i/s)", "Delta", widths: widths)

    v1_yjit[:with_yjit].each do |label, v1_entry|
      v2_entry = v2_yjit[:with_yjit][label] || v2_yjit[:with_yjit][label.to_s]
      next unless v2_entry

      v1_ips = v1_entry[:ips] || v1_entry["ips"]
      v2_ips = v2_entry[:ips] || v2_entry["ips"]
      delta = v1_ips.to_f.positive? ? ((v2_ips - v1_ips).to_f / v1_ips * 100) : 0

      printf "%-28s  %14s  %14s  %s\n",
        label.to_s,
        format_number(v1_ips.to_f.round(1)),
        format_number(v2_ips.to_f.round(1)),
        colorize_delta(delta, higher_is_better: true)
    end
  end
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
section_header("Summary")

if v1s[:ips_tasks] && v2s[:ips_tasks]
  v1_success = v1s[:ips_tasks][:success] || v1s[:ips_tasks]["success"]
  v2_success = v2s[:ips_tasks][:success] || v2s[:ips_tasks]["success"]

  if v1_success && v2_success
    ratio = v2_success[:ips].to_f / v1_success[:ips]
    change = ((ratio - 1) * 100).round(1)
    verdict = ratio >= 1.0 ? green("FASTER") : red("SLOWER")

    puts "  Task execution (success):  v2 is #{format('%.2fx', ratio)} #{verdict} than v1 (#{colorize_delta(change, higher_is_better: true)})"
  end
end

if v1s[:memory] && v2s[:memory]
  v1_mem_success = v1s[:memory].find { |m| m[:label] == "success" }
  v2_mem_success = v2s[:memory].find { |m| m[:label] == "success" }

  if v1_mem_success && v2_mem_success
    mem_ratio = v2_mem_success[:total_allocated_memsize].to_f / v1_mem_success[:total_allocated_memsize]
    mem_change = ((mem_ratio - 1) * 100).round(1)
    mem_verdict = mem_ratio <= 1.0 ? green("LESS") : red("MORE")

    puts "  Memory (success):          v2 uses #{format('%.2fx', mem_ratio)} #{mem_verdict} memory than v1 (#{colorize_delta(mem_change, higher_is_better: false)})"
  end
end

puts

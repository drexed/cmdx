# frozen_string_literal: true

# Result matchers
require_relative "result_matchers/be_successful_task"
require_relative "result_matchers/be_failed_task"
require_relative "result_matchers/be_skipped_task"
require_relative "result_matchers/be_executed"
require_relative "result_matchers/be_state_matchers"
require_relative "result_matchers/be_status_matchers"
require_relative "result_matchers/have_good_outcome"
require_relative "result_matchers/have_bad_outcome"
require_relative "result_matchers/have_runtime"
require_relative "result_matchers/have_metadata"
require_relative "result_matchers/have_empty_metadata"
require_relative "result_matchers/have_context"
require_relative "result_matchers/have_preserved_context"
require_relative "result_matchers/have_caused_failure"
require_relative "result_matchers/have_thrown_failure"
require_relative "result_matchers/have_received_thrown_failure"
require_relative "result_matchers/have_chain_index"

# Task matchers
require_relative "task_matchers/be_well_formed_task"
require_relative "task_matchers/have_cmd_setting"
require_relative "task_matchers/have_middleware"
require_relative "task_matchers/have_callback"
require_relative "task_matchers/have_parameter"
require_relative "task_matchers/have_executed_callbacks"

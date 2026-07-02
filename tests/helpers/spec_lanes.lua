local M = {}

M.unit = {
    "tests/spec/test_runner_spec.lua",
    "tests/spec/auth_spec.lua",
    "tests/spec/auth_source_spec.lua",
    "tests/spec/bank_ledger_spec.lua",
    "tests/spec/bank_ledger_scanner_spec.lua",
    "tests/spec/chat_filters_spec.lua",
    "tests/spec/chat_output_spec.lua",
    "tests/spec/crafted_quality_spec.lua",
    "tests/spec/dashboard_spec.lua",
    "tests/spec/diff_spec.lua",
    "tests/spec/exports_spec.lua",
    "tests/spec/history_spec.lua",
    "tests/spec/inventory_quality_spec.lua",
    "tests/spec/item_catalog_spec.lua",
    "tests/spec/item_catalog_extract_spec.lua",
    "tests/spec/item_catalog_index_spec.lua",
    "tests/spec/item_catalog_maintainer_spec.lua",
    "tests/spec/item_catalog_merge_spec.lua",
    "tests/spec/item_catalog_target_spec.lua",
    "tests/spec/item_display_spec.lua",
    "tests/spec/minimums_portability_spec.lua",
    "tests/spec/officer_note_blacklist_spec.lua",
    "tests/spec/onboarding_spec.lua",
    "tests/spec/planning_spec.lua",
    "tests/spec/release_operator_skill_spec.lua",
    "tests/spec/release_workflow_spec.lua",
    "tests/spec/requests_spec.lua",
    "tests/spec/sync_spec.lua",
    "tests/spec/sync_ledger_digest_spec.lua",
    "tests/spec/sync_ledger_manifest_spec.lua",
    "tests/spec/sync_manual_actions_spec.lua",
    "tests/spec/sync_peer_state_spec.lua",
    "tests/spec/store_spec.lua",
}

M.ui = {
    "tests/spec/ui_spec.lua",
    "tests/spec/ui_about_spec.lua",
    "tests/spec/ui_bank_ledger_spec.lua",
    "tests/spec/ui_crafted_quality_live_regression_spec.lua",
    "tests/spec/ui_dashboard_spec.lua",
    "tests/spec/ui_exports_spec.lua",
    "tests/spec/ui_history_spec.lua",
    "tests/spec/ui_inventory_spec.lua",
    "tests/spec/ui_minimums_spec.lua",
    "tests/spec/ui_minimums_sync_spec.lua",
    "tests/spec/ui_options_spec.lua",
    "tests/spec/ui_requests_spec.lua",
    "tests/spec/ui_search_results_control_spec.lua",
    "tests/spec/ui_shell_spec.lua",
    "tests/spec/ui_table_spec.lua",
}

M.integration = {
    "tests/spec/in_game_unit_spec.lua",
    "tests/spec/live_smoke_spec.lua",
    "tests/spec/slash_commands_spec.lua",
    "tests/spec/toc_spec.lua",
}

return M

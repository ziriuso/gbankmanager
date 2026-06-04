package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
local runner = require("tests.helpers.test_runner")

local specs = {
    "tests/spec/test_runner_spec.lua",
    "tests/spec/diff_spec.lua",
    "tests/spec/auth_spec.lua",
    "tests/spec/auth_source_spec.lua",
    "tests/spec/exports_spec.lua",
    "tests/spec/history_spec.lua",
    "tests/spec/bank_ledger_spec.lua",
    "tests/spec/dashboard_spec.lua",
    "tests/spec/chat_output_spec.lua",
    "tests/spec/inventory_quality_spec.lua",
    "tests/spec/minimums_portability_spec.lua",
    "tests/spec/planning_spec.lua",
    "tests/spec/requests_spec.lua",
    "tests/spec/sync_spec.lua",
    "tests/spec/sync_ledger_manifest_spec.lua",
    "tests/spec/store_spec.lua",
    "tests/spec/item_catalog_spec.lua",
    "tests/spec/item_catalog_target_spec.lua",
    "tests/spec/item_catalog_extract_spec.lua",
    "tests/spec/item_catalog_merge_spec.lua",
    "tests/spec/item_catalog_maintainer_spec.lua",
}

runner.run_specs(specs)

print("PASS tests/run_unit.lua")

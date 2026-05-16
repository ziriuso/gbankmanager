package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local specs = {
    "tests/spec/ui_spec.lua",
    "tests/spec/ui_shell_spec.lua",
    "tests/spec/ui_search_results_control_spec.lua",
    "tests/spec/ui_table_spec.lua",
    "tests/spec/ui_requests_spec.lua",
    "tests/spec/ui_exports_spec.lua",
    "tests/spec/ui_minimums_spec.lua",
    "tests/spec/ui_options_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_ui.lua")

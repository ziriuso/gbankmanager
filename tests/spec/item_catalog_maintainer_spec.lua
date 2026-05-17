local assert = require("tests.helpers.assert")

local baseDir = ".\\tests\\tmp\\item-catalog-maintainer"

local function join_path(...)
    return table.concat({ ... }, "\\")
end

local function normalize_path(value)
    return value:gsub("/", "\\")
end

local function shell_quote(value)
    return tostring(value):gsub("'", "''")
end

local function powershell_argument(value)
    return string.format('"%s"', tostring(value):gsub('"', '\\"'))
end

local function powershell_command_argument(value)
    return string.format('"%s"', tostring(value):gsub('"', '\\"'))
end

local function powershell_single_quote(value)
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function absolute_path(path)
    local handle = io.popen(string.format("powershell -NoProfile -Command \"[System.IO.Path]::GetFullPath('%s')\"", shell_quote(path)))
    assert.truthy(handle ~= nil, "absolute path helper should start a powershell process")

    local value = handle:read("*a")
    handle:close()
    return normalize_path((value or ""):gsub("%s+$", ""))
end

local function ensure_directory(path)
    os.execute(string.format("powershell -NoProfile -ExecutionPolicy Bypass -Command \"New-Item -ItemType Directory -Force -Path '%s' | Out-Null\"", shell_quote(path)))
end

local function write_text_file(path, content)
    local handle = io.open(path, "wb")
    assert.truthy(handle ~= nil, "fixture writer should open the target file")
    handle:write(content)
    handle:close()
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    assert.truthy(handle ~= nil, "fixture reader should open the target file")
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local function run_process(command)
    local handle = io.popen(command)
    assert.truthy(handle ~= nil, "powershell process should start successfully")

    local output = handle:read("*a") or ""
    handle:close()
    return output
end

local invocationCounter = 0

local function run_powershell_file(scriptPath, args, wrapperDirectory)
    invocationCounter = invocationCounter + 1
    local wrapperPath = join_path(wrapperDirectory, string.format("invoke-%03d.ps1", invocationCounter))
    local wrapperLines = {
        "$scriptPath = " .. powershell_single_quote(absolute_path(scriptPath)),
        "$argumentList = @(",
    }

    for index, arg in ipairs(args) do
        local suffix = ""
        if index < #args then
            suffix = ","
        end
        table.insert(wrapperLines, "    " .. powershell_single_quote(arg) .. suffix)
    end

    table.insert(wrapperLines, ")")
    table.insert(wrapperLines, "& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @argumentList")
    table.insert(wrapperLines, "$exitCode = $LASTEXITCODE")
    table.insert(wrapperLines, "Write-Output ('__EXIT__:' + $exitCode)")
    write_text_file(wrapperPath, table.concat(wrapperLines, "\r\n"))

    return run_process(table.concat({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File",
        powershell_command_argument(wrapperPath),
    }, " "))
end

local function run_status(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Get-ItemCatalogMaintainerStatus.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "status command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local function run_deploy(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Deploy-AddonsToTarget.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "deploy command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local function json_string_field(content, field)
    local value = content:match('"' .. field .. '"%s*:%s*"([^"]*)"')
    if value == nil then
        return nil
    end

    return value:gsub("\\\\", "\\")
end

local function json_array_contains(content, field, expectedValue)
    local arrayContent = content:match('"' .. field .. '"%s*:%s*%[(.-)%]')
    if arrayContent == nil then
        return false
    end

    return arrayContent:find(string.format('"%s"', expectedValue:gsub("\\", "\\\\")), 1, true) ~= nil
end

local fixtureDir = join_path(baseDir, "fixtures")
local outputDir = join_path(baseDir, "outputs")
local wrapperDir = join_path(baseDir, "wrappers")
ensure_directory(fixtureDir)
ensure_directory(outputDir)
ensure_directory(wrapperDir)

local wowFixtureRoot = join_path(fixtureDir, "wow-root")
local wowFixtureRootAbsolute = absolute_path(wowFixtureRoot)
ensure_directory(join_path(wowFixtureRoot, "_retail_"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Data"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Data", "en_US"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Interface"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Interface", "AddOns"))

local progressPath = join_path(outputDir, "item-catalog-refresh-retail.json")
write_text_file(progressPath, [[
{
  "target": "Retail",
  "status": "completed",
  "phase": "build",
  "phaseStatus": "completed",
  "mode": "Fresh",
  "build": "11.2.7.63796",
  "wowRoot": "]] .. wowFixtureRootAbsolute:gsub("\\", "\\\\") .. [[",
  "clientDirectory": "]] .. join_path(wowFixtureRootAbsolute, "_retail_"):gsub("\\", "\\\\") .. [[",
  "outputLuaPath": "]] .. absolute_path(join_path(outputDir, "Data.lua")):gsub("\\", "\\\\") .. [[",
  "progressPath": "]] .. absolute_path(progressPath):gsub("\\", "\\\\") .. [[",
  "phaseCompletedAt": "2026-05-17T03:15:00.000Z",
  "completedAt": "2026-05-17T03:15:00.000Z",
  "completedPhases": ["extraction", "merge", "build"],
  "buildSucceeded": true,
  "nextStep": "addon-rebuilt"
}
]])

local syncedStatus = run_status({
    "-Target", "Retail",
    "-WoWRoot", powershell_argument(wowFixtureRoot),
    "-ProgressPath", powershell_argument(progressPath),
})

assert.truthy(syncedStatus.success, "maintainer status command should succeed for a resolved target fixture")
assert.equal(0, syncedStatus.exitCode, "maintainer status command should exit 0 when status can be read")
assert.equal("ok", json_string_field(syncedStatus.output, "status"), "maintainer status command should report an ok wrapper status")
assert.equal("synced", json_string_field(syncedStatus.output, "syncStatus"), "maintainer status command should report synced when the last build completed successfully")
assert.equal("11.2.7.63796", json_string_field(syncedStatus.output, "build"), "maintainer status command should surface the last synced build")
assert.equal("2026-05-17T03:15:00.000Z", json_string_field(syncedStatus.output, "lastSyncAt"), "maintainer status command should surface the last completed sync timestamp")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_"), json_string_field(syncedStatus.output, "clientDirectory"), "maintainer status command should report the resolved client directory")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_", "Interface", "AddOns"), json_string_field(syncedStatus.output, "addOnsDirectory"), "maintainer status command should report the deploy target directory")

local neverSyncedProgressPath = join_path(outputDir, "never-synced-retail.json")
local neverSyncedStatus = run_status({
    "-Target", "Retail",
    "-WoWRoot", powershell_argument(wowFixtureRoot),
    "-ProgressPath", powershell_argument(neverSyncedProgressPath),
})

assert.truthy(neverSyncedStatus.success, "maintainer status command should still succeed when no saved progress exists yet")
assert.equal("never_synced", json_string_field(neverSyncedStatus.output, "syncStatus"), "maintainer status command should report never_synced before the first refresh")
assert.equal("", json_string_field(neverSyncedStatus.output, "lastSyncAt"), "maintainer status command should leave last sync blank before any refresh")
assert.equal("", json_string_field(neverSyncedStatus.output, "build"), "maintainer status command should leave build blank before any refresh")

local sourceRoot = join_path(fixtureDir, "repo-source")
local mainAddonPath = join_path(sourceRoot, "GBankManager")
local itemDataAddonPath = join_path(sourceRoot, "GBankManager_ItemData")
ensure_directory(mainAddonPath)
ensure_directory(itemDataAddonPath)
write_text_file(join_path(mainAddonPath, "GBankManager.toc"), "## Interface: 110207\r\n")
write_text_file(join_path(itemDataAddonPath, "GBankManager_ItemData.toc"), "## Interface: 110207\r\n")

local deploy = run_deploy({
    "-Target", "Retail",
    "-WoWRoot", powershell_argument(wowFixtureRoot),
    "-MainAddonPath", powershell_argument(mainAddonPath),
    "-ItemDataAddonPath", powershell_argument(itemDataAddonPath),
})

assert.truthy(deploy.success, "deploy command should succeed for a resolved target fixture")
assert.equal(0, deploy.exitCode, "deploy command should exit 0 when addon folders copy successfully")
assert.equal("deployed", json_string_field(deploy.output, "status"), "deploy command should report a deployed status")
assert.equal("Retail", json_string_field(deploy.output, "target"), "deploy command should preserve the selected target")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_", "Interface", "AddOns"), json_string_field(deploy.output, "addOnsDirectory"), "deploy command should report the selected AddOns directory")
assert.truthy(json_array_contains(deploy.output, "deployedAddons", "GBankManager"), "deploy command should report the main addon in its deployed addon list")
assert.truthy(json_array_contains(deploy.output, "deployedAddons", "GBankManager_ItemData"), "deploy command should report the item-data addon in its deployed addon list")
assert.equal("## Interface: 110207\r\n", read_text_file(join_path(wowFixtureRoot, "_retail_", "Interface", "AddOns", "GBankManager", "GBankManager.toc")), "deploy command should copy the main addon into the target AddOns directory")
assert.equal("## Interface: 110207\r\n", read_text_file(join_path(wowFixtureRoot, "_retail_", "Interface", "AddOns", "GBankManager_ItemData", "GBankManager_ItemData.toc")), "deploy command should copy the item-data addon into the target AddOns directory")

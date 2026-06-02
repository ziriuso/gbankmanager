local assert = require("tests.helpers.assert")
local powershell = require("tests.helpers.powershell")
local PATH_SEPARATOR = powershell.path_separator()

local function join_path(...)
    return table.concat({ ... }, PATH_SEPARATOR)
end

local function normalize_path(value)
    return powershell.normalize_host_path(value)
end

local function shell_quote(value)
    return powershell.shell_quote(value)
end

local function absolute_path(path)
    local handle = powershell.absolute_path(path)
    assert.truthy(handle ~= nil, "absolute path helper should start a powershell process")

    local value = handle:read("*a")
    handle:close()
    return normalize_path((value or ""):gsub("%s+$", ""))
end

local function powershell_argument(value)
    return powershell.argument(absolute_path(value))
end

local function ensure_directory(path)
    powershell.ensure_directory(path)
end

local function write_text_file(path, content)
    local handle = io.open(path, "wb")
    assert.truthy(handle ~= nil, "fixture writer should open the target file")
    handle:write(content)
    handle:close()
end

local function remove_path_if_exists(path)
    powershell.remove_path_if_exists(path)
end

local function powershell_command_argument(value)
    return powershell.command_argument(value)
end

local function run_process(command)
    local handle = io.popen(command)
    assert.truthy(handle ~= nil, "powershell process should start successfully")

    local output = handle:read("*a") or ""
    local ok, _, status = handle:close()
    assert.truthy(ok == true or status == 0, "powershell process should exit successfully")
    return output
end

local function read_json_query(path, expression)
    local command = string.format(
        "%s",
        powershell.json_query_command(path, expression)
    )

    local handle = io.popen(command)
    assert.truthy(handle ~= nil, "json query helper should start a powershell process")

    local output = handle:read("*a") or ""
    handle:close()
    return (output:gsub("%s+$", ""))
end

local function run_target_resolution(args, env)
    local commandParts = {
        powershell.executable(),
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
    }
    local scriptParts = {}

    if env then
        for key, value in pairs(env) do
            table.insert(scriptParts, string.format("$env:%s = '%s';", key, shell_quote(value)))
        end
    end

    table.insert(scriptParts, "& '.\\tools\\catalog\\Resolve-WoWTarget.ps1'")

    for _, arg in ipairs(args) do
        table.insert(scriptParts, arg)
    end

    table.insert(scriptParts, "-Json")
    table.insert(commandParts, powershell_command_argument(table.concat(scriptParts, " ")))

    local content = run_process(table.concat(commandParts, " "))
    assert.truthy(type(content) == "string" and content ~= "", "target resolution command should emit json")

    local target = content:match('"target"%s*:%s*"([^"]+)"')
    local root = content:match('"wowRoot"%s*:%s*"([^"]+)"')
    local client = content:match('"clientDirectory"%s*:%s*"([^"]+)"')
    local locale = content:match('"locale"%s*:%s*"([^"]+)"')
    local product = content:match('"product"%s*:%s*"([^"]+)"')

    return {
        target = target,
        wowRoot = root and normalize_path(root:gsub("\\\\", "\\")) or nil,
        clientDirectory = client and normalize_path(client:gsub("\\\\", "\\")) or nil,
        locale = locale,
        product = product,
    }
end

local function run_target_resolution_failure(args, env)
    local commandParts = {
        powershell.executable(),
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
    }
    local scriptParts = {}

    if env then
        for key, value in pairs(env) do
            table.insert(scriptParts, string.format("$env:%s = '%s';", key, shell_quote(value)))
        end
    end

    table.insert(scriptParts, "$ErrorActionPreference = 'Stop';")
    table.insert(scriptParts, "try {")
    table.insert(scriptParts, "& '.\\tools\\catalog\\Resolve-WoWTarget.ps1'")
    for _, arg in ipairs(args) do
        table.insert(scriptParts, arg)
    end
    table.insert(scriptParts, "-Json | Out-Null;")
    table.insert(scriptParts, "Write-Output 'UNEXPECTED_SUCCESS'; exit 0")
    table.insert(scriptParts, "} catch { Write-Output $_.Exception.Message; exit 1 }")
    table.insert(commandParts, powershell_command_argument(table.concat(scriptParts, " ")))

    local handle = io.popen(table.concat(commandParts, " "))
    assert.truthy(handle ~= nil, "failing powershell process should start successfully")

    local output = handle:read("*a") or ""
    handle:close()
    assert.truthy(output:find("UNEXPECTED_SUCCESS", 1, true) == nil, "resolver failure helper should not report a false success")
    return output
end

local function parse_json_fields(content, fields)
    local result = {}

    for _, field in ipairs(fields) do
        local value = content:match('"' .. field .. '"%s*:%s*"([^"]*)"')
        if value ~= nil then
            result[field] = value:gsub("\\\\", "\\")
            result[field] = normalize_path(result[field])
        end
    end

    return result
end

local function json_array_contains(content, field, expectedValue)
    local arrayContent = content:match('"' .. field .. '"%s*:%s*%[(.-)%]')
    if arrayContent == nil then
        return false
    end

    local normalizedArray = normalize_path(arrayContent:gsub("\\\\", "\\"))
    return normalizedArray:find(string.format('"%s"', normalize_path(expectedValue)), 1, true) ~= nil
end

local function json_field_uses_array_shape(content, field)
    return content:find('"' .. field .. '"%s*:%s*%[', 1) ~= nil
end

local function run_refresh(args, env)
    local commandParts = {
        powershell.executable(),
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
    }
    local scriptParts = {}

    if env then
        for key, value in pairs(env) do
            table.insert(scriptParts, string.format("$env:%s = '%s';", key, shell_quote(value)))
        end
    end

    table.insert(scriptParts, "& '.\\tools\\catalog\\Refresh-ItemCatalog.ps1'")

    for _, arg in ipairs(args) do
        table.insert(scriptParts, arg)
    end

    table.insert(scriptParts, "-Json")
    table.insert(scriptParts, "; Write-Output ('__EXIT__:' + $LASTEXITCODE)")
    table.insert(commandParts, powershell_command_argument(table.concat(scriptParts, " ")))

    local handle = io.popen(table.concat(commandParts, " "))
    assert.truthy(handle ~= nil, "refresh command should start a powershell process")

    local output = handle:read("*a") or ""
    handle:close()
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "refresh command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")
    assert.truthy(type(output) == "string" and output ~= "", "refresh command should emit json output")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local baseDir = join_path(".", "tests", "tmp", "item-catalog-target")
local fixtureRoot = join_path(baseDir, "wow-fixture")
local fixtureRootAbsolute = absolute_path(fixtureRoot)
local targetManifestPath = join_path(baseDir, "refresh-manifest.json")
local targetOutputLuaPath = join_path(baseDir, "refresh-item-data.lua")
local targetProgressPath = join_path(baseDir, "refresh-progress.json")
local targetPartialRowsPath = join_path(baseDir, "refresh-progress.partial.jsonl")
local missingResumeProgressPath = join_path(baseDir, "missing-resume-progress.json")
local missingResumePartialRowsPath = join_path(baseDir, "missing-resume-progress.partial.jsonl")
ensure_directory(baseDir)
write_text_file(targetManifestPath, [[
{
  "source": "target_spec_fixture",
  "generatedAt": "2026-05-14",
  "region": "us",
  "itemCount": 1,
  "unresolvedCount": 0,
  "items": [
    {
      "itemID": 990001,
      "name": "Target Spec Rune",
      "quality": 2,
      "qualityName": "Uncommon",
      "craftedQuality": null,
      "craftedQualityIcon": null,
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-14T00:00:00.000Z",
      "unresolved": false,
      "source": "target_spec_fixture",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US"
    }
  ]
}
]])
ensure_directory(join_path(fixtureRoot, "_retail_"))
ensure_directory(join_path(fixtureRoot, "_ptr_"))
ensure_directory(join_path(fixtureRoot, "_beta_"))
ensure_directory(join_path(fixtureRoot, "_retail_", "Data"))
ensure_directory(join_path(fixtureRoot, "_retail_", "Data", "en_US"))

local retail = run_target_resolution({
    "-Target", "Retail",
    "-WoWRoot", powershell_argument(fixtureRoot),
})
assert.equal("Retail", retail.target, "retail target should resolve with its explicit name")
assert.equal(join_path(fixtureRootAbsolute, "_retail_"), retail.clientDirectory, "retail target should use the retail client directory")
assert.equal("wow", retail.product, "retail target should default to the main wow product")
assert.equal("en_US", retail.locale, "retail target should default to en_US locale")

local ptr = run_target_resolution({
    "-Target", "PTR",
    "-WoWRoot", powershell_argument(fixtureRoot),
})
assert.equal("PTR", ptr.target, "ptr target should resolve with its explicit name")
assert.equal(join_path(fixtureRootAbsolute, "_ptr_"), ptr.clientDirectory, "ptr target should use the ptr client directory")
assert.equal("wowt", ptr.product, "ptr target should use the ptr product code")

local xptrRoot = join_path(baseDir, "xptr-root")
local xptrRootAbsolute = absolute_path(xptrRoot)
ensure_directory(join_path(xptrRoot, "_xptr_"))

local xptr = run_target_resolution({
    "-Target", "PTR",
    "-WoWRoot", powershell_argument(xptrRoot),
})
assert.equal("PTR", xptr.target, "ptr target should still resolve against the newer xptr client layout")
assert.equal(join_path(xptrRootAbsolute, "_xptr_"), xptr.clientDirectory, "ptr target should accept the newer xptr client directory name when ptr is absent")
assert.equal("wowt", xptr.product, "ptr target should keep the ptr product code when xptr is resolved")

local beta = run_target_resolution({
    "-Target", "Beta",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-Locale", "fr_FR",
})
assert.equal("Beta", beta.target, "beta target should resolve with its explicit name")
assert.equal(join_path(fixtureRootAbsolute, "_beta_"), beta.clientDirectory, "beta target should use the beta client directory")
assert.equal("wow_beta", beta.product, "beta target should use the beta product code")
assert.equal("fr_FR", beta.locale, "caller locale overrides should flow through unchanged")

local customRoot = join_path(baseDir, "custom-root")
local customRootAbsolute = absolute_path(customRoot)
ensure_directory(join_path(customRoot, "_retail_"))

local override = run_target_resolution({
    "-Target", "Retail",
    "-WoWRoot", powershell_argument(customRoot),
    "-Locale", "de_DE",
})
assert.equal(customRootAbsolute, override.wowRoot, "WoWRoot override should be preserved in the resolved contract")
assert.equal(join_path(customRootAbsolute, "_retail_"), override.clientDirectory, "WoWRoot override should drive client directory selection")
assert.equal("de_DE", override.locale, "WoWRoot overrides should still allow explicit locale overrides")

local clientOverride = run_target_resolution({
    "-Target", "Retail",
    "-ClientDirectory", powershell_argument(join_path(customRoot, "_retail_")),
})
assert.equal(join_path(customRootAbsolute, "_retail_"), clientOverride.clientDirectory, "ClientDirectory should take precedence when explicitly provided")
assert.equal(customRootAbsolute, clientOverride.wowRoot, "ClientDirectory should derive the install root from the provided client path")

local detected = run_target_resolution({
    "-Target", "Retail",
}, {
    GBM_WOW_DEFAULT_ROOTS = fixtureRootAbsolute,
})
assert.equal(fixtureRootAbsolute, detected.wowRoot, "default root environment overrides should support auto-detect tests")
assert.equal(join_path(fixtureRootAbsolute, "_retail_"), detected.clientDirectory, "auto-detect should resolve the target client directory from the configured root list")

local missing = run_target_resolution_failure({
    "-Target", "Retail",
}, {
    GBM_WOW_DEFAULT_ROOTS = join_path(baseDir, "missing-root"),
    GBM_WOW_DISABLE_FALLBACK_ROOTS = "1",
})
assert.truthy(missing:find("Unable to locate a World of Warcraft install", 1, true) ~= nil, "resolver should fail clearly when no install root can be detected")

local missingMode = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(not missingMode.success, "refresh should fail when neither -Fresh nor -Resume is provided")
assert.truthy(missingMode.output:find("exactly one", 1, true) ~= nil, "refresh should explain that maintainers must choose exactly one execution mode")

local conflictingMode = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
    "-Fresh",
    "-Resume",
})
assert.truthy(not conflictingMode.success, "refresh should fail when both -Fresh and -Resume are provided")
assert.truthy(conflictingMode.output:find("exactly one", 1, true) ~= nil, "refresh should explain that fresh and resume cannot be combined")

remove_path_if_exists(missingResumeProgressPath)
remove_path_if_exists(missingResumePartialRowsPath)
local missingResumeState = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ProgressPath", powershell_argument(missingResumeProgressPath),
    "-PartialRowsPath", powershell_argument(missingResumePartialRowsPath),
    "-Resume",
})
assert.truthy(not missingResumeState.success, "refresh should fail when resume is requested without saved progress state")
assert.truthy(missingResumeState.output:find("progress", 1, true) ~= nil, "refresh should explain that resume needs saved progress state")

local resumeExtractionOutputPath = join_path(baseDir, "resume-extracted.json")
write_text_file(resumeExtractionOutputPath, [[
{
  "source": "local_client_item_db2",
  "target": "Retail",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "generatedAt": "2026-05-14",
  "itemCount": 1,
  "items": [
    {
      "itemID": 990001,
      "name": "Target Spec Rune",
      "quality": 2,
      "qualityName": "Uncommon",
      "craftedQuality": null,
      "craftedQualityIcon": null,
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-14T00:00:00.000Z"
    }
  ]
}
]])
write_text_file(targetProgressPath, [[
{
  "target": "Retail",
  "catalogProfile": "Full",
  "mode": "Fresh",
  "status": "completed",
  "phase": "extraction",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "wowRoot": "]] .. fixtureRootAbsolute:gsub("\\", "\\\\") .. [[",
  "clientDirectory": "]] .. join_path(fixtureRootAbsolute, "_retail_"):gsub("\\", "\\\\") .. [[",
  "outputPath": "]] .. absolute_path(resumeExtractionOutputPath):gsub("\\", "\\\\") .. [[",
  "partialRowsPath": "]] .. absolute_path(targetPartialRowsPath):gsub("\\", "\\\\") .. [[",
  "startedAt": "2026-05-14T00:00:00.000Z",
  "updatedAt": "2026-05-14T00:05:00.000Z",
  "completedAt": "2026-05-14T00:05:00.000Z",
  "resumeSupported": true,
  "rawRowCountSeen": 1,
  "normalizedCountWritten": 1,
  "lastProcessedItemID": 990001,
  "lastProcessedIndex": 1,
  "highestSeenItemID": 990001,
  "failureClass": null,
  "failureMessage": null
}
]])

local resumedRefresh = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-Resume",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ManifestPath", powershell_argument(targetManifestPath),
    "-OutputLuaPath", powershell_argument(targetOutputLuaPath),
    "-ExtractionOutputPath", powershell_argument(resumeExtractionOutputPath),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(resumedRefresh.success, "refresh should resume successfully from a completed extraction state")
assert.equal(0, resumedRefresh.exitCode, "refresh should exit 0 when resume continues through merge and build")
assert.truthy(resumedRefresh.output:find('"mode":"Resume"', 1, true) ~= nil, "refresh should report resume mode when continuing from saved extraction state")
assert.truthy(resumedRefresh.output:find('"nextStep":"addon-rebuilt"', 1, true) ~= nil, "refresh resume should continue through generated addon rebuild")
assert.truthy(resumedRefresh.output:find('"phase":"build"', 1, true) ~= nil, "refresh resume should report the final completed build phase")
assert.truthy(resumedRefresh.output:find('"phaseStatus":"completed"', 1, true) ~= nil, "refresh resume should report completed phase status after rebuild")
assert.equal("extraction,merge,build", read_json_query(targetProgressPath, "@($data.completedPhases) -join ','"), "refresh resume should persist completed phases through extraction, merge, and build")
assert.equal("build", read_json_query(targetProgressPath, "$data.phase"), "refresh resume should persist the last completed phase in progress state")
assert.equal("completed", read_json_query(targetProgressPath, "$data.phaseStatus"), "refresh resume should persist the completed phase status in progress state")

write_text_file(targetProgressPath, [[
{
  "target": "Retail",
  "catalogProfile": "Full",
  "mode": "Resume",
  "status": "completed",
  "phase": "merge",
  "phaseStatus": "completed",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "wowRoot": "]] .. fixtureRootAbsolute:gsub("\\", "\\\\") .. [[",
  "clientDirectory": "]] .. join_path(fixtureRootAbsolute, "_retail_"):gsub("\\", "\\\\") .. [[",
  "progressPath": "]] .. absolute_path(targetProgressPath):gsub("\\", "\\\\") .. [[",
  "outputPath": "]] .. absolute_path(resumeExtractionOutputPath):gsub("\\", "\\\\") .. [[",
  "partialRowsPath": "]] .. absolute_path(targetPartialRowsPath):gsub("\\", "\\\\") .. [[",
  "startedAt": "2026-05-14T00:00:00.000Z",
  "updatedAt": "2026-05-14T00:06:00.000Z",
  "phaseStartedAt": "2026-05-14T00:05:30.000Z",
  "phaseCompletedAt": "2026-05-14T00:06:00.000Z",
  "resumeSupported": true,
  "rawRowCountSeen": 1,
  "normalizedCountWritten": 1,
  "lastProcessedItemID": 990001,
  "lastProcessedIndex": 1,
  "highestSeenItemID": 990001,
  "completedPhases": ["extraction", "merge"],
  "mergeSummary": {
    "status": "merged",
    "manifestPath": "]] .. absolute_path(targetManifestPath):gsub("\\", "\\\\") .. [[",
    "itemCount": 1,
    "addedCount": 0,
    "refreshedCount": 1,
    "retainedCount": 0,
    "deprecatedCount": 0
  },
  "failureClass": null,
  "failureMessage": null
}
]])

local resumedBuildOnly = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-Resume",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ManifestPath", powershell_argument(targetManifestPath),
    "-OutputLuaPath", powershell_argument(targetOutputLuaPath),
    "-ExtractionOutputPath", powershell_argument(resumeExtractionOutputPath),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(resumedBuildOnly.success, "refresh should resume successfully from a completed merge state")
assert.equal(0, resumedBuildOnly.exitCode, "refresh should exit 0 when resume only needs the build phase")
assert.truthy(resumedBuildOnly.output:find('"mode":"Resume"', 1, true) ~= nil, "build-only resume should still report resume mode")
assert.truthy(resumedBuildOnly.output:find('"phase":"build"', 1, true) ~= nil, "build-only resume should finish in the build phase")

local refreshReady = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-Fresh",
    "-WoWRoot", powershell_argument(fixtureRoot),
    "-ManifestPath", powershell_argument(targetManifestPath),
    "-OutputLuaPath", powershell_argument(targetOutputLuaPath),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(refreshReady.success, "refresh shell should succeed when the selected target has the required data paths")
assert.equal(0, refreshReady.exitCode, "refresh shell should exit 0 when the selected target is ready for extraction")
local readySummary = parse_json_fields(refreshReady.output, {
    "status",
    "target",
    "failureClass",
    "message",
    "mode",
    "progressPath",
    "clientDirectory",
    "dataDirectory",
    "localeDirectory",
})
assert.equal("ready", readySummary.status, "refresh shell should report readiness when validation passes")
assert.equal("Retail", readySummary.target, "refresh shell should report the resolved target")
assert.equal("Fresh", readySummary.mode, "refresh shell should report the selected execution mode")
assert.equal(absolute_path(targetProgressPath), readySummary.progressPath, "refresh shell should report the selected progress path")
assert.equal(join_path(fixtureRootAbsolute, "_retail_"), readySummary.clientDirectory, "refresh shell should report the validated client directory")
assert.equal(join_path(fixtureRootAbsolute, "_retail_", "Data"), readySummary.dataDirectory, "refresh shell should report the validated data directory")
assert.equal(join_path(fixtureRootAbsolute, "_retail_", "Data", "en_US"), readySummary.localeDirectory, "refresh shell should report the validated locale directory")
assert.truthy(readySummary.failureClass == nil, "refresh readiness should not include a failure classification")
assert.truthy(readySummary.message:find("Extraction was skipped", 1, true) ~= nil, "refresh readiness should explain when extraction is skipped for a validated target layout")

local xptrSharedFixture = join_path(baseDir, "wow-fixture-xptr-shared-data")
local xptrSharedFixtureAbsolute = absolute_path(xptrSharedFixture)
ensure_directory(join_path(xptrSharedFixture, "_xptr_"))
ensure_directory(join_path(xptrSharedFixture, "Data"))
ensure_directory(join_path(xptrSharedFixture, "Data", "wowxptr"))

local ptrSharedReady = run_refresh({
    "-Target", "PTR",
    "-CatalogProfile", "Full",
    "-Fresh",
    "-WoWRoot", powershell_argument(xptrSharedFixture),
    "-ManifestPath", powershell_argument(targetManifestPath),
    "-OutputLuaPath", powershell_argument(targetOutputLuaPath),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(ptrSharedReady.success, "refresh shell should accept PTR installs that store extracted data under the shared wowxptr root data folder")
assert.equal(0, ptrSharedReady.exitCode, "refresh shell should exit 0 when PTR shared-root data validation passes")
local ptrSharedSummary = parse_json_fields(ptrSharedReady.output, {
    "status",
    "target",
    "clientDirectory",
    "dataDirectory",
    "localeDirectory",
})
assert.equal("ready", ptrSharedSummary.status, "PTR shared-root data should still report readiness")
assert.equal("PTR", ptrSharedSummary.target, "PTR shared-root data should keep the resolved target")
assert.equal(join_path(xptrSharedFixtureAbsolute, "_xptr_"), ptrSharedSummary.clientDirectory, "PTR shared-root data should report the resolved xptr client directory")
assert.equal(join_path(xptrSharedFixtureAbsolute, "Data"), ptrSharedSummary.dataDirectory, "PTR shared-root data should report the root Data directory")
assert.equal(join_path(xptrSharedFixtureAbsolute, "Data", "wowxptr"), ptrSharedSummary.localeDirectory, "PTR shared-root data should report the wowxptr product directory")

local unknownTarget = run_refresh({
    "-Target", "Unknown",
    "-CatalogProfile", "Full",
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
    "-Fresh",
})
assert.truthy(not unknownTarget.success, "refresh shell should fail for an unsupported target")
assert.truthy(unknownTarget.exitCode ~= 0, "refresh shell should exit nonzero for an unsupported target")
local unknownSummary = parse_json_fields(unknownTarget.output, {
    "status",
    "failureClass",
    "target",
    "requestedTarget",
    "message",
})
assert.equal("failed", unknownSummary.status, "unknown target should be reported as a failed refresh")
assert.equal("environment", unknownSummary.failureClass, "unknown target should be classified as an environment failure")
assert.equal("Unknown", unknownSummary.requestedTarget, "unknown target failures should preserve the requested target for diagnostics")
assert.truthy(unknownTarget.output:find("Unknown", 1, true) ~= nil, "unknown target failures should mention the requested target")
assert.truthy(json_field_uses_array_shape(unknownTarget.output, "requiredPaths"), "unknown target failures should keep requiredPaths as an array-shaped field")
assert.truthy(json_field_uses_array_shape(unknownTarget.output, "checks"), "unknown target failures should keep checks as an array-shaped field")

local missingInstall = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
    "-Fresh",
}, {
    GBM_WOW_DEFAULT_ROOTS = join_path(baseDir, "missing-root"),
    GBM_WOW_DISABLE_FALLBACK_ROOTS = "1",
})
assert.truthy(not missingInstall.success, "refresh shell should fail when no install root can be detected")
assert.truthy(missingInstall.exitCode ~= 0, "refresh shell should exit nonzero when no install root can be detected")
local missingInstallSummary = parse_json_fields(missingInstall.output, {
    "status",
    "failureClass",
    "requestedTarget",
    "message",
})
assert.equal("failed", missingInstallSummary.status, "missing install root should be reported as a failed refresh")
assert.equal("environment", missingInstallSummary.failureClass, "missing install root should be classified as an environment failure")
assert.equal("Retail", missingInstallSummary.requestedTarget, "missing install failures should preserve the requested target")
assert.truthy(missingInstallSummary.message:find("Unable to locate a World of Warcraft install", 1, true) ~= nil, "missing install failures should explain how maintainers can provide a root")
assert.truthy(json_field_uses_array_shape(missingInstall.output, "requiredPaths"), "missing install failures should keep requiredPaths as an array-shaped field")
assert.truthy(json_field_uses_array_shape(missingInstall.output, "checks"), "missing install failures should keep checks as an array-shaped field")

local missingLocaleFixture = join_path(baseDir, "wow-fixture-missing-locale")
local missingLocaleFixtureAbsolute = absolute_path(missingLocaleFixture)
ensure_directory(join_path(missingLocaleFixture, "_retail_"))
ensure_directory(join_path(missingLocaleFixture, "_retail_", "Data"))

local missingDataPaths = run_refresh({
    "-Target", "Retail",
    "-CatalogProfile", "Full",
    "-Fresh",
    "-WoWRoot", powershell_argument(missingLocaleFixture),
    "-ProgressPath", powershell_argument(targetProgressPath),
    "-PartialRowsPath", powershell_argument(targetPartialRowsPath),
})
assert.truthy(not missingDataPaths.success, "refresh shell should fail when required client data paths are missing")
assert.truthy(missingDataPaths.exitCode ~= 0, "refresh shell should exit nonzero when required client data paths are missing")
local missingPathSummary = parse_json_fields(missingDataPaths.output, {
    "status",
    "failureClass",
    "target",
    "message",
})
assert.equal("failed", missingPathSummary.status, "missing client data paths should be reported as a failed refresh")
assert.equal("environment", missingPathSummary.failureClass, "missing client data paths should be classified as an environment failure")
assert.equal("Retail", missingPathSummary.target, "missing client data path failures should report the resolved target")
assert.truthy(missingPathSummary.message:find("required client data paths", 1, true) ~= nil, "missing client data path failures should explain the validation gap")
assert.truthy(json_array_contains(missingDataPaths.output, "missingPaths", join_path(missingLocaleFixtureAbsolute, "_retail_", "Data", "en_US")), "missing client data path failures should report the missing locale directory")

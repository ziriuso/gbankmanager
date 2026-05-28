package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local powershell = require("tests.helpers.powershell")
local PATH_SEPARATOR = powershell.path_separator()
local baseDir = table.concat({ ".", "tests", "tmp", "item-catalog-merge" }, PATH_SEPARATOR)

local function join_path(...)
    return table.concat({ ... }, PATH_SEPARATOR)
end

local function normalize_path(value)
    return powershell.normalize_host_path(value)
end

local function shell_quote(value)
    return powershell.shell_quote(value)
end

local function powershell_argument(value)
    local handle = powershell.absolute_path(value)
    assert.truthy(handle ~= nil, "absolute path helper should start a powershell process")
    local resolvedValue = handle:read("*a")
    handle:close()
    return normalize_path((resolvedValue or ""):gsub("%s+$", ""))
end

local function powershell_command_argument(value)
    return powershell.command_argument(value)
end

local function powershell_single_quote(value)
    return powershell.single_quote(value)
end

local function absolute_path(path)
    local handle = powershell.absolute_path(path)
    assert.truthy(handle ~= nil, "absolute path helper should start a powershell process")

    local value = handle:read("*a")
    handle:close()
    return normalize_path((value or ""):gsub("%s+$", ""))
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
    local repoRoot = absolute_path(".")
    local wrapperLines = {
        "$repoRoot = " .. powershell_single_quote(repoRoot),
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
    table.insert(wrapperLines, "Set-Location -LiteralPath $repoRoot")
    table.insert(wrapperLines, "& " .. powershell_single_quote(powershell.executable()) .. " -NoProfile -ExecutionPolicy Bypass -File $scriptPath @argumentList")
    table.insert(wrapperLines, "$exitCode = $LASTEXITCODE")
    table.insert(wrapperLines, "Write-Output ('__EXIT__:' + $exitCode)")
    write_text_file(wrapperPath, table.concat(wrapperLines, "\r\n"))

    return run_process(table.concat({
        powershell.executable(),
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File",
        powershell_command_argument(absolute_path(wrapperPath)),
    }, " "))
end

local function run_merge(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Merge-ExtractedItemCatalog.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "merge command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local function run_import(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Import-LearnedItemCatalog.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "learned import command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local function run_refresh(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Refresh-ItemCatalog.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "refresh command should emit an explicit exit code marker")
    output = output:gsub("%s*__EXIT__:%-?%d+%s*$", "")

    return {
        output = output,
        success = exitCode == 0,
        exitCode = exitCode,
    }
end

local function run_build(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Build-ItemDataAddon.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "build command should emit an explicit exit code marker")
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

    local normalized = value:gsub("\\\\", "\\")
    if normalized:find("[/\\]") then
        return normalize_path(normalized)
    end

    return normalized
end

local function json_number_field(content, field)
    local value = content:match('"' .. field .. '"%s*:%s*(%-?%d+)')
    if value == nil then
        return nil
    end

    return tonumber(value)
end

local function json_boolean_field(content, field)
    if content:match('"' .. field .. '"%s*:%s*true') ~= nil then
        return true
    end

    if content:match('"' .. field .. '"%s*:%s*false') ~= nil then
        return false
    end

    return nil
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

local function read_item_field(path, itemID, field)
    return read_json_query(path, string.format("(($data.items | Where-Object { $_.itemID -eq %d } | Select-Object -First 1).%s)", itemID, field))
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    assert.truthy(handle ~= nil, "text fixture reader should open the target file")
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local function read_bundle_text_from_toc(tocPath)
    local base = tocPath:match("^(.*)[/\\][^/\\]+$") or "."
    local pieces = {}

    for line in io.lines(tocPath) do
        local entry = (line:gsub("^%s+", ""):gsub("%s+$", ""))
        if entry ~= "" and not entry:match("^##") then
            local filePath = join_path(base, normalize_path(entry))
            pieces[#pieces + 1] = read_text_file(filePath)
        end
    end

    return table.concat(pieces, "\n")
end

local fixtureDir = join_path(baseDir, "fixtures")
local outputDir = join_path(baseDir, "outputs")
local wrapperDir = join_path(baseDir, "wrappers")
ensure_directory(fixtureDir)
ensure_directory(outputDir)
ensure_directory(wrapperDir)

local manifestPath = join_path(fixtureDir, "item-catalog-input.json")
write_text_file(manifestPath, [[
{
  "source": "starter_seed",
  "generatedAt": "2026-05-13",
  "region": "us",
  "itemCount": 4,
  "unresolvedCount": 4,
  "items": [
    {
      "itemID": 7007,
      "name": "Algari Mana Oil",
      "quality": null,
      "qualityName": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "starter_seed"
    },
    {
      "itemID": 132514,
      "name": "Auto-Hammer Prototype",
      "quality": 1,
      "qualityName": "Common",
      "craftedQuality": 2,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier2",
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-10T00:00:00.000Z",
      "unresolved": false,
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.6.00000",
      "locale": "en_US"
    },
    {
      "itemID": 242273,
      "name": "Blooming Feast Learned",
      "quality": null,
      "qualityName": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "starter_seed"
    },
    {
      "itemID": 900000,
      "name": "Retired Prototype Relic",
      "quality": 2,
      "qualityName": "Uncommon",
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-10T00:00:00.000Z",
      "unresolved": false,
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.6.00000",
      "locale": "en_US"
    }
  ]
}
]])

local extractedPath = join_path(fixtureDir, "item-catalog-extracted.json")
write_text_file(extractedPath, [[
{
  "source": "local_client_item_db2",
  "target": "Retail",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "generatedAt": "2026-05-14",
  "itemCount": 3,
  "items": [
    {
      "itemID": 132514,
      "name": "Auto-Hammer",
      "quality": 2,
      "qualityName": "Uncommon",
      "craftedQuality": 3,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier3",
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-14T12:34:56.000Z"
    },
    {
      "itemID": 240154,
      "name": "Arcanoweave Spellthread",
      "quality": 4,
      "qualityName": "Epic",
      "itemLink": "|cffa335ee|Hitem:240154::::::::80:::::|h[Arcanoweave Spellthread]|h|r",
      "itemString": "item:240154::::::::80:::::",
      "craftedQuality": 5,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier5",
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-14T12:34:56.000Z"
    },
    {
      "itemID": 242273,
      "name": "Blooming Feast",
      "quality": 3,
      "qualityName": "Rare",
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-14T12:34:56.000Z"
    }
  ]
}
]])

local mergedPath = join_path(outputDir, "item-catalog-merged.json")
local mergedAbsolute = absolute_path(mergedPath)

local merge = run_merge({
    "-ManifestPath", powershell_argument(manifestPath),
    "-ExtractedPath", powershell_argument(extractedPath),
    "-OutputPath", powershell_argument(mergedPath),
})

assert.truthy(merge.success, "merge command should succeed for a valid manifest and normalized extraction payload")
assert.equal(0, merge.exitCode, "merge command should exit 0 when manifest merge succeeds")
assert.equal("merged", json_string_field(merge.output, "status"), "merge command should report a merged status")
assert.equal(5, json_number_field(merge.output, "itemCount"), "merge command should report the retained and added row count")
assert.equal(mergedAbsolute, json_string_field(merge.output, "manifestPath"), "merge command should report the written manifest path")

assert.equal("5", read_json_query(mergedPath, "$data.items.Count"), "merge output should retain existing rows and add new extracted ones")
assert.equal("7007,132514,240154,242273,900000", read_json_query(mergedPath, "(($data.items | ForEach-Object { $_.itemID }) -join ',')"), "merge output should sort rows deterministically by itemID")

assert.equal("Arcanoweave Spellthread", read_item_field(mergedPath, 240154, "name"), "merge should add newly extracted rows")
assert.equal("Auto-Hammer", read_item_field(mergedPath, 132514, "name"), "merge should replace older confirmed metadata with fresher extracted metadata")
assert.equal("2", read_item_field(mergedPath, 132514, "quality"), "merge should persist the fresher extracted quality")
assert.equal("3", read_item_field(mergedPath, 132514, "craftedQuality"), "merge should persist the fresher extracted crafted quality tier")
assert.equal("Professions-ChatIcon-Quality-Tier3", read_item_field(mergedPath, 132514, "craftedQualityIcon"), "merge should persist the fresher extracted crafted quality icon")
assert.equal("11.2.7.63796", read_item_field(mergedPath, 132514, "build"), "merge should stamp refreshed rows with the selected build")
assert.equal("Retail", read_item_field(mergedPath, 132514, "target"), "merge should stamp refreshed rows with the selected target")
assert.equal("2026-05-14T12:34:56.000Z", read_item_field(mergedPath, 132514, "lastVerifiedAt"), "merge should preserve the extracted verification timestamp for refreshed rows")

assert.equal("confirmed", read_item_field(mergedPath, 242273, "status"), "merge should let confirmed extracted rows supersede learned rows")
assert.equal("Blooming Feast", read_item_field(mergedPath, 242273, "name"), "merge should replace learned placeholder metadata when a confirmed extracted row arrives")
assert.equal("learned", read_item_field(mergedPath, 7007, "status"), "merge should retain learned rows that are absent from the extracted payload")
assert.equal("deprecated", read_item_field(mergedPath, 900000, "status"), "merge should intentionally retain missing confirmed rows as deprecated candidates instead of deleting them")
assert.equal("5", read_item_field(mergedPath, 240154, "craftedQuality"), "merge should retain crafted quality data for newly added extracted rows")
assert.equal("Professions-ChatIcon-Quality-Tier5", read_item_field(mergedPath, 240154, "craftedQualityIcon"), "merge should retain crafted quality icons for newly added extracted rows")
assert.equal("|cffa335ee|Hitem:240154::::::::80:::::|h[Arcanoweave Spellthread]|h|r", read_item_field(mergedPath, 240154, "itemLink"), "merge should retain trusted hyperlinks for newly added extracted rows")
assert.equal("item:240154::::::::80:::::", read_item_field(mergedPath, 240154, "itemString"), "merge should retain trusted item strings for newly added extracted rows")

local staleManifestPath = join_path(fixtureDir, "stale-protection-input.json")
write_text_file(staleManifestPath, [[
{
  "source": "local_client_item_db2",
  "generatedAt": "2026-05-14",
  "region": "us",
  "itemCount": 1,
  "unresolvedCount": 0,
  "items": [
    {
      "itemID": 600001,
      "name": "Fresh Manifest Record",
      "quality": 4,
      "qualityName": "Epic",
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-16T08:00:00.000Z",
      "unresolved": false,
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.8.70000",
      "locale": "en_US"
    }
  ]
}
]])

local staleExtractedPath = join_path(fixtureDir, "stale-protection-extracted.json")
write_text_file(staleExtractedPath, [[
{
  "source": "local_client_item_db2",
  "target": "Retail",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "generatedAt": "2026-05-14",
  "itemCount": 1,
  "items": [
    {
      "itemID": 600001,
      "name": "Older Extracted Record",
      "quality": 2,
      "qualityName": "Uncommon",
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-14T12:34:56.000Z"
    }
  ]
}
]])

local staleMergedPath = join_path(outputDir, "stale-protection-merged.json")
local staleMerge = run_merge({
    "-ManifestPath", powershell_argument(staleManifestPath),
    "-ExtractedPath", powershell_argument(staleExtractedPath),
    "-OutputPath", powershell_argument(staleMergedPath),
})

assert.truthy(staleMerge.success, "merge should still succeed when the extracted row is older than the existing confirmed row")
assert.equal("Fresh Manifest Record", read_item_field(staleMergedPath, 600001, "name"), "merge should keep the fresher existing confirmed metadata when the extracted row is older")
assert.equal("4", read_item_field(staleMergedPath, 600001, "quality"), "merge should preserve the fresher existing confirmed quality when the extracted row is older")
assert.equal("11.2.8.70000", read_item_field(staleMergedPath, 600001, "build"), "merge should preserve the newer existing confirmed build when the extracted row is older")
assert.equal("2026-05-16T08:00:00.000Z", read_item_field(staleMergedPath, 600001, "lastVerifiedAt"), "merge should preserve the newer existing confirmation timestamp when the extracted row is older")

local wowFixtureRoot = join_path(baseDir, "wow-fixture")
local wowFixtureRootAbsolute = absolute_path(wowFixtureRoot)
ensure_directory(join_path(wowFixtureRoot, "_retail_"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Data"))
ensure_directory(join_path(wowFixtureRoot, "_retail_", "Data", "en_US"))
write_text_file(join_path(wowFixtureRoot, "_retail_", ".build.info"), "Build Key!CDN Key!Install Key!IM Size!CDN Hosts!CDN Path!Tags!Armadillo!Last Activated!Version!KeyRing!Product!Region!Build UID\r\n")

local refreshManifestPath = join_path(fixtureDir, "refresh-item-catalog-input.json")
write_text_file(refreshManifestPath, [[
{
  "source": "starter_seed",
  "generatedAt": "2026-05-13",
  "region": "us",
  "itemCount": 2,
  "unresolvedCount": 2,
  "items": [
    {
      "itemID": 132514,
      "name": "Auto-Hammer Prototype",
      "quality": null,
      "qualityName": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "starter_seed"
    },
    {
      "itemID": 7007,
      "name": "Algari Mana Oil",
      "quality": null,
      "qualityName": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "starter_seed"
    }
  ]
}
]])

local refreshExtractionFixturePath = join_path(fixtureDir, "refresh-item-sparse-fixture.json")
write_text_file(refreshExtractionFixturePath, [[
{
  "build": "11.2.7.63796",
  "baseRows": [
    { "itemID": 132514, "Display_lang": "Auto-Hammer", "OverallQualityID": 2 },
    { "itemID": 242273, "Display_lang": "Blooming Feast", "OverallQualityID": 1 }
  ],
  "hotfixRows": [
    { "itemID": 242273, "Display_lang": "Blooming Feast", "OverallQualityID": 3 },
    { "itemID": 240154, "Display_lang": "Arcanoweave Spellthread", "OverallQualityID": 4, "CraftingQualityID": 5, "ItemLink": "|cffa335ee|Hitem:240154::::::::80:::::|h[Arcanoweave Spellthread]|h|r", "ItemString": "item:240154::::::::80:::::" }
  ]
}
]])

local refreshOutputPath = join_path(outputDir, "refresh-normalized-items.json")
local refreshOutputAbsolute = absolute_path(refreshOutputPath)
local refreshLuaPath = join_path(outputDir, "refresh-item-data.lua")
local refreshLuaAbsolute = absolute_path(refreshLuaPath)
local refreshTocPath = join_path(outputDir, "GBankManager_ItemData.toc")
local refreshSearchBootstrapPath = join_path(outputDir, "SearchBootstrap.lua")
local refreshProgressPath = join_path(outputDir, "refresh-progress.json")
local refreshPartialRowsPath = join_path(outputDir, "refresh-progress.partial.jsonl")
local refresh = run_refresh({
    "-Target", "Retail",
    "-Fresh",
    "-CatalogProfile", "Full",
    "-WoWRoot", powershell_argument(wowFixtureRoot),
    "-ExtractionFixturePath", powershell_argument(refreshExtractionFixturePath),
    "-ExtractionOutputPath", powershell_argument(refreshOutputPath),
    "-ManifestPath", powershell_argument(refreshManifestPath),
    "-OutputLuaPath", powershell_argument(refreshLuaPath),
    "-ProgressPath", powershell_argument(refreshProgressPath),
    "-PartialRowsPath", powershell_argument(refreshPartialRowsPath),
})

assert.truthy(refresh.success, "refresh command should succeed when extraction and manifest merge succeed")
assert.equal(0, refresh.exitCode, "refresh command should exit 0 after merge and generated addon rebuild succeed")
assert.equal("ready", json_string_field(refresh.output, "status"), "refresh command should continue to report a ready status after merge and rebuild")
assert.equal("addon-rebuilt", json_string_field(refresh.output, "nextStep"), "refresh command should now report the completed generated addon rebuild step")
assert.equal(refreshOutputAbsolute, json_string_field(refresh.output, "normalizedRowsPath"), "refresh command should still report the normalized extraction output path")
assert.equal(3, json_number_field(refresh.output, "normalizedCount"), "refresh command should still surface the normalized row count")
assert.equal(refreshLuaAbsolute, json_string_field(refresh.output, "outputLuaPath"), "refresh command should report the rebuilt addon data path")
assert.equal(4, json_number_field(refresh.output, "generatedItemCount"), "refresh command should report the rebuilt addon item count")
assert.equal(true, json_boolean_field(refresh.output, "buildSucceeded"), "refresh command should report a successful generated addon rebuild")
assert.truthy(refresh.output:find("rebuild succeeded", 1, true) ~= nil, "refresh command should explain that generated addon rebuild succeeded")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_"), json_string_field(refresh.output, "clientDirectory"), "refresh command should continue to report the validated client directory")
assert.equal("4", read_json_query(refreshManifestPath, "$data.items.Count"), "refresh command should merge normalized rows into the checked-in manifest path while retaining learned rows")
assert.equal("confirmed", read_item_field(refreshManifestPath, 132514, "status"), "refresh command should promote extracted rows into the manifest")
assert.equal("learned", read_item_field(refreshManifestPath, 7007, "status"), "refresh command should preserve existing learned rows that are still absent from extraction")
local rebuiltLua = read_text_file(refreshLuaPath)
assert.truthy(rebuiltLua:find("staticItemCatalog", 1, true) ~= nil, "refresh command should now emit a shim Data.lua that resolves the generated bundled catalog payload")
assert.truthy(rebuiltLua:find("Arcanoweave Spellthread", 1, true) == nil, "shim Data.lua should stay compact instead of embedding generated item rows directly")
assert.truthy(read_text_file(refreshSearchBootstrapPath):find("staticItemSearchBootstrap", 1, true) ~= nil, "refresh command should emit a search bootstrap alongside the generated output")
local rebuiltBundleText = read_bundle_text_from_toc(refreshTocPath)
assert.truthy(rebuiltBundleText:find("Arcanoweave Spellthread", 1, true) ~= nil, "refresh command should rebuild generated addon bundle data from the merged manifest contents")
assert.truthy(rebuiltBundleText:find("craftedQuality = 5", 1, true) ~= nil, "refresh command should rebuild generated addon bundle data with crafted quality tiers when available")
assert.truthy(rebuiltBundleText:find("craftedQualityIcon = \"Professions-ChatIcon-Quality-Tier5\"", 1, true) ~= nil, "refresh command should rebuild generated addon bundle data with crafted quality icons when available")
assert.truthy(rebuiltBundleText:find("itemLink = \"|cffa335ee|Hitem:240154::::::::80:::::|h[Arcanoweave Spellthread]|h|r\"", 1, true) ~= nil, "refresh command should rebuild generated addon bundle data with trusted hyperlink fields when available")
assert.truthy(rebuiltBundleText:find("itemString = \"item:240154::::::::80:::::\"", 1, true) ~= nil, "refresh command should rebuild generated addon bundle data with trusted item-string fields when available")
assert.truthy(rebuiltLua:find("status =", 1, true) == nil, "rebuilt addon data should stay compact instead of embedding manifest status metadata")
assert.truthy(rebuiltLua:find("lastVerifiedAt", 1, true) == nil, "rebuilt addon data should omit raw extraction verification payload fields")

local buildManifestPath = join_path(fixtureDir, "build-active-only-input.json")
write_text_file(buildManifestPath, [[
{
  "source": "build_fixture",
  "generatedAt": "2026-05-15",
  "region": "us",
  "itemCount": 3,
  "unresolvedCount": 0,
  "items": [
    {
      "itemID": 7007,
      "name": "Algari Mana Oil",
      "quality": null,
      "qualityName": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "build_fixture"
    },
    {
      "itemID": 132514,
      "name": "Auto-Hammer",
      "quality": 2,
      "qualityName": "Uncommon",
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-15T00:00:00.000Z",
      "unresolved": false,
      "source": "build_fixture"
    },
    {
      "itemID": 900000,
      "name": "Deprecated Test Item",
      "quality": 1,
      "qualityName": "Common",
      "status": "deprecated",
      "lastVerifiedAt": "2026-05-14T00:00:00.000Z",
      "unresolved": false,
      "source": "build_fixture"
    }
  ]
}
]])

local buildOnlyAddonDir = join_path(outputDir, "build-active-only-addon")
ensure_directory(buildOnlyAddonDir)
local buildOnlyLuaPath = join_path(buildOnlyAddonDir, "Data.lua")
local buildOnly = run_build({
    "-ManifestPath", powershell_argument(buildManifestPath),
    "-OutputLuaPath", powershell_argument(buildOnlyLuaPath),
})
assert.truthy(buildOnly.success, "build command should succeed for a manifest containing deprecated rows")
assert.equal(0, buildOnly.exitCode, "build command should exit 0 when addon generation succeeds")
assert.equal("built", json_string_field(buildOnly.output, "status"), "build command should report a built status")
assert.equal(2, json_number_field(buildOnly.output, "itemCount"), "build command should export only active non-deprecated rows into the shipped addon data")
local buildOnlyBundleText = read_bundle_text_from_toc(join_path(buildOnlyAddonDir, "GBankManager_ItemData.toc"))
assert.truthy(buildOnlyBundleText:find("Algari Mana Oil", 1, true) ~= nil, "build command should keep active learned rows in the shipped addon data")
assert.truthy(buildOnlyBundleText:find("Auto-Hammer", 1, true) ~= nil, "build command should keep active confirmed rows in the shipped addon data")
assert.truthy(buildOnlyBundleText:find("Deprecated Test Item", 1, true) == nil, "build command should exclude deprecated manifest history from the shipped addon data")

local learnedManifestPath = join_path(fixtureDir, "learned-import-input.json")
write_text_file(learnedManifestPath, [[
{
  "source": "starter_seed",
  "generatedAt": "2026-05-13",
  "region": "us",
  "itemCount": 2,
  "unresolvedCount": 1,
  "items": [
    {
      "itemID": 132514,
      "name": "Auto-Hammer",
      "quality": 2,
      "qualityName": "Uncommon",
      "status": "confirmed",
      "lastVerifiedAt": "2026-05-14T12:34:56.000Z",
      "unresolved": false,
      "source": "local_client_item_db2",
      "target": "Retail",
      "build": "11.2.7.63796",
      "locale": "en_US"
    },
    {
      "itemID": 242273,
      "name": "Blooming Feast Placeholder",
      "quality": null,
      "qualityName": null,
      "status": "unresolved",
      "lastVerifiedAt": null,
      "unresolved": true,
      "source": "starter_seed"
    }
  ]
}
]])

local learnedRowsPath = join_path(fixtureDir, "learned-import-rows.json")
write_text_file(learnedRowsPath, [[
{
  "source": "addon_saved_search_catalog",
  "exportedAt": "2026-05-14T19:30:00.000Z",
  "items": [
    {
      "itemID": 132514,
      "name": "Auto-Hammer Learned Override",
      "quality": 1,
      "qualityName": "Common"
    },
    {
      "itemID": 242273,
      "name": "Blooming Feast Learned",
      "quality": 3,
      "qualityName": "Rare"
    },
    {
      "itemID": 555555,
      "name": "PTR Test Potion",
      "quality": 2,
      "qualityName": "Uncommon",
      "itemLink": "|cff1eff00|Hitem:555555::::::::80:::::|h[PTR Test Potion]|h|r",
      "itemString": "item:555555::::::::80:::::",
      "craftedQuality": 4,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier4"
    }
  ]
}
]])

local learnedMergedPath = join_path(outputDir, "learned-import-merged.json")
local learnedImport = run_import({
    "-ManifestPath", powershell_argument(learnedManifestPath),
    "-LearnedRowsPath", powershell_argument(learnedRowsPath),
    "-OutputPath", powershell_argument(learnedMergedPath),
})

assert.truthy(learnedImport.success, "learned import should succeed for addon-exported learned rows")
assert.equal(0, learnedImport.exitCode, "learned import should exit 0 when manifest import succeeds")
assert.equal("imported", json_string_field(learnedImport.output, "status"), "learned import should report an imported status")
assert.equal(3, json_number_field(learnedImport.output, "itemCount"), "learned import should report the merged manifest row count")
assert.equal("learned", read_item_field(learnedMergedPath, 555555, "status"), "learned import should add brand-new learned rows")
assert.equal("PTR Test Potion", read_item_field(learnedMergedPath, 555555, "name"), "learned import should persist imported learned metadata for new rows")
assert.equal("4", read_item_field(learnedMergedPath, 555555, "craftedQuality"), "learned import should persist crafted quality tiers for new rows")
assert.equal("Professions-ChatIcon-Quality-Tier4", read_item_field(learnedMergedPath, 555555, "craftedQualityIcon"), "learned import should persist crafted quality icons for new rows")
assert.equal("|cff1eff00|Hitem:555555::::::::80:::::|h[PTR Test Potion]|h|r", read_item_field(learnedMergedPath, 555555, "itemLink"), "learned import should persist trusted hyperlinks for new rows")
assert.equal("item:555555::::::::80:::::", read_item_field(learnedMergedPath, 555555, "itemString"), "learned import should persist trusted item strings for new rows")
assert.equal("Auto-Hammer", read_item_field(learnedMergedPath, 132514, "name"), "learned import should not overwrite existing confirmed metadata with learned rows")
assert.equal("2", read_item_field(learnedMergedPath, 132514, "quality"), "learned import should preserve confirmed quality when a learned row collides")
assert.equal("learned", read_item_field(learnedMergedPath, 242273, "status"), "learned import should promote unresolved or placeholder rows into learned rows")
assert.equal("Blooming Feast Learned", read_item_field(learnedMergedPath, 242273, "name"), "learned import should refresh non-confirmed metadata from the learned import payload")

local learnedSupersedeExtractedPath = join_path(fixtureDir, "learned-import-confirmed-refresh.json")
write_text_file(learnedSupersedeExtractedPath, [[
{
  "source": "local_client_item_db2",
  "target": "PTR",
  "build": "11.2.8.70000",
  "locale": "en_US",
  "generatedAt": "2026-05-15",
  "itemCount": 1,
  "items": [
    {
      "itemID": 555555,
      "name": "PTR Test Potion Confirmed",
      "quality": 4,
      "qualityName": "Epic",
      "craftedQuality": 5,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier5",
      "status": "confirmed",
      "source": "local_client_item_db2",
      "target": "PTR",
      "build": "11.2.8.70000",
      "locale": "en_US",
      "lastVerifiedAt": "2026-05-15T08:00:00.000Z"
    }
  ]
}
]])

local learnedSupersedePath = join_path(outputDir, "learned-import-superseded.json")
local learnedSupersedeMerge = run_merge({
    "-ManifestPath", powershell_argument(learnedMergedPath),
    "-ExtractedPath", powershell_argument(learnedSupersedeExtractedPath),
    "-OutputPath", powershell_argument(learnedSupersedePath),
})

assert.truthy(learnedSupersedeMerge.success, "confirmed refresh should still merge after a learned import")
assert.equal("confirmed", read_item_field(learnedSupersedePath, 555555, "status"), "later confirmed refreshes should supersede learned rows")
assert.equal("PTR Test Potion Confirmed", read_item_field(learnedSupersedePath, 555555, "name"), "later confirmed refreshes should replace learned metadata")
assert.equal("5", read_item_field(learnedSupersedePath, 555555, "craftedQuality"), "later confirmed refreshes should replace learned crafted quality tiers")
assert.equal("Professions-ChatIcon-Quality-Tier5", read_item_field(learnedSupersedePath, 555555, "craftedQualityIcon"), "later confirmed refreshes should replace learned crafted quality icons")
assert.equal("PTR", read_item_field(learnedSupersedePath, 555555, "target"), "later confirmed refreshes should stamp learned rows with target metadata once confirmed")
assert.equal("11.2.8.70000", read_item_field(learnedSupersedePath, 555555, "build"), "later confirmed refreshes should stamp learned rows with build metadata once confirmed")

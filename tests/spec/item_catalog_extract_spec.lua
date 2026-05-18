local assert = require("tests.helpers.assert")
local powershell = require("tests.helpers.powershell")
local PATH_SEPARATOR = powershell.path_separator()
local baseDir = table.concat({ ".", "tests", "tmp", "item-catalog-extract" }, PATH_SEPARATOR)

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

local function run_extract(args)
    local invocationArgs = {}
    for _, arg in ipairs(args) do
        table.insert(invocationArgs, arg)
    end
    table.insert(invocationArgs, "-Json")

    local output = run_powershell_file(".\\tools\\catalog\\Extract-ItemDb2.ps1", invocationArgs, join_path(baseDir, "wrappers"))
    local exitCode = tonumber(output:match("__EXIT__:(%-?%d+)"))
    assert.truthy(exitCode ~= nil, "extract command should emit an explicit exit code marker")
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

local function read_item_field_is_null(path, itemID, field)
    return read_json_query(path, string.format("($null -eq (($data.items | Where-Object { $_.itemID -eq %d } | Select-Object -First 1).%s))", itemID, field))
end

local fixtureDir = join_path(baseDir, "fixtures")
local outputDir = join_path(baseDir, "outputs")
local wrapperDir = join_path(baseDir, "wrappers")
ensure_directory(fixtureDir)
ensure_directory(outputDir)
ensure_directory(wrapperDir)

local extractFixturePath = join_path(fixtureDir, "item-sparse-fixture.json")
write_text_file(extractFixturePath, [[
{
  "build": "11.2.7.63796",
  "baseRows": [
    { "itemID": 132514, "Display_lang": "Auto-Hammer", "OverallQualityID": 2, "ClassID": 7, "SubclassID": 11 },
    { "itemID": 242273, "Display_lang": "Blooming Feast", "OverallQualityID": 1, "ClassID": 0, "SubclassID": 5 },
    { "itemID": 241326, "Display_lang": "Flask of the Shattered Sun", "OverallQualityID": 1, "ExpansionID": 11, "ItemLevel": 278, "ClassID": 0, "SubclassID": 1 },
    { "itemID": 241327, "Display_lang": "Flask of the Shattered Sun", "OverallQualityID": 1, "ExpansionID": 11, "ItemLevel": 295, "ClassID": 0, "SubclassID": 1 },
    { "itemID": 243733, "Display_lang": "Thalassian Phoenix Oil", "OverallQualityID": 1, "ExpansionID": 11, "ItemLevel": 278, "ClassID": 0, "SubclassID": 6 },
    { "itemID": 243734, "Display_lang": "Thalassian Phoenix Oil", "OverallQualityID": 1, "ExpansionID": 11, "ItemLevel": 295, "ClassID": 0, "SubclassID": 6 },
    { "itemID": 212281, "Display_lang": "Flask of Alchemical Chaos", "OverallQualityID": 1, "ExpansionID": 10, "ItemLevel": 80, "ClassID": 0, "SubclassID": 1 },
    { "itemID": 212282, "Display_lang": "Flask of Alchemical Chaos", "OverallQualityID": 1, "ExpansionID": 10, "ItemLevel": 83, "ClassID": 0, "SubclassID": 1 },
    { "itemID": 212283, "Display_lang": "Flask of Alchemical Chaos", "OverallQualityID": 1, "ExpansionID": 10, "ItemLevel": 85, "ClassID": 0, "SubclassID": 1 },
    { "itemID": 555001, "Display_lang": "Legacy Duplicate Test", "OverallQualityID": 4, "ExpansionID": 10, "ItemLevel": 1, "ClassID": 2, "SubclassID": 7 },
    { "itemID": 555002, "Display_lang": "Legacy Duplicate Test", "OverallQualityID": 4, "ExpansionID": 10, "ItemLevel": 584, "ClassID": 2, "SubclassID": 7 },
    { "itemID": 250001, "Display_lang": "Sunless Satchel", "OverallQualityID": 2, "ExpansionID": 11, "ClassID": 1, "SubclassID": 0, "InventoryType": 18 },
    { "itemID": 250002, "Display_lang": "Stormcut Diamond", "OverallQualityID": 3, "ExpansionID": 11, "ClassID": 3, "SubclassID": 9 },
    { "itemID": 250003, "Display_lang": "Blessed Alloy", "OverallQualityID": 1, "ExpansionID": 11, "ClassID": 7, "SubclassID": 6 },
    { "itemID": 250004, "Display_lang": "Stormguard Greatsword", "OverallQualityID": 4, "ExpansionID": 11, "ClassID": 2, "SubclassID": 8, "InventoryType": 17 },
    { "itemID": 999999, "Display_lang": "", "OverallQualityID": 4, "ClassID": 0, "SubclassID": 0 },
    { "itemID": 0, "Display_lang": "Ignored Placeholder", "OverallQualityID": 2, "ClassID": 0, "SubclassID": 0 }
  ],
  "hotfixRows": [
    { "itemID": 242273, "Display_lang": "Blooming Feast", "OverallQualityID": 3, "ClassID": 0, "SubclassID": 5 },
    { "itemID": 240154, "Display_lang": "Arcanoweave Spellthread", "OverallQualityID": 4, "CraftingQualityID": 5, "ExpansionID": 11, "ClassID": 8, "SubclassID": 0 }
  ]
}
]])

local normalizedOutputPath = join_path(outputDir, "normalized-items.json")
local normalizedOutputAbsolute = absolute_path(normalizedOutputPath)
local progressDir = join_path(baseDir, "state")
ensure_directory(progressDir)
local extractProgressPath = join_path(progressDir, "extract-progress.json")
local extractPartialRowsPath = join_path(progressDir, "extract-progress.partial.jsonl")

local extract = run_extract({
    "-Target", "Retail",
    "-Mode", "Fresh",
    "-CatalogProfile", "Full",
    "-Locale", "en_US",
    "-FixturePath", powershell_argument(extractFixturePath),
    "-OutputPath", powershell_argument(normalizedOutputPath),
    "-ProgressPath", powershell_argument(extractProgressPath),
    "-PartialRowsPath", powershell_argument(extractPartialRowsPath),
})
assert.truthy(extract.success, "extract command should succeed for a valid normalization fixture")
assert.equal(0, extract.exitCode, "extract command should exit 0 when normalization succeeds")
assert.equal("extracted", json_string_field(extract.output, "status"), "extract command should report an extracted status after normalization succeeds")
assert.equal("Retail", json_string_field(extract.output, "target"), "extract command should preserve the selected target")
assert.equal("Full", json_string_field(extract.output, "catalogProfile"), "extract command should report the selected catalog profile")
assert.equal("en_US", json_string_field(extract.output, "locale"), "extract command should preserve the requested locale")
assert.equal("11.2.7.63796", json_string_field(extract.output, "build"), "extract command should report the source build")
assert.equal(17, json_number_field(extract.output, "rawRowCount"), "extract command should report the pre-normalization row count after hotfix merge")
assert.equal(16, json_number_field(extract.output, "normalizedCount"), "extract command should keep only the valid addon-facing normalized rows")
assert.equal(normalizedOutputAbsolute, json_string_field(extract.output, "normalizedRowsPath"), "extract command should report the written normalized rows path")
assert.equal("Fresh", json_string_field(extract.output, "mode"), "extract command should report the selected execution mode")
assert.equal(absolute_path(extractProgressPath), json_string_field(extract.output, "progressPath"), "extract command should report the selected progress path")
assert.equal(absolute_path(extractPartialRowsPath), json_string_field(extract.output, "partialRowsPath"), "extract command should report the partial rows path")
assert.equal(true, json_boolean_field(extract.output, "resumeSupported"), "extract command should report that extraction supports resume state")
assert.equal(999999, json_number_field(extract.output, "lastProcessedItemID"), "extract command should report the last processed source item id after a complete fresh run")
assert.equal(16, json_number_field(extract.output, "normalizedCountWritten"), "extract command should report the number of rows written to resumable output")

assert.equal("16", read_json_query(normalizedOutputPath, "$data.items.Count"), "normalized output should contain only the valid addon-facing rows")
assert.equal("Auto-Hammer", read_item_field(normalizedOutputPath, 132514, "name"), "extract normalization should preserve the base item name")
assert.equal("2", read_item_field(normalizedOutputPath, 132514, "quality"), "extract normalization should preserve the base item quality")
assert.equal("Uncommon", read_item_field(normalizedOutputPath, 132514, "qualityName"), "extract normalization should map quality ids into quality names")
assert.equal("True", read_item_field_is_null(normalizedOutputPath, 132514, "craftedQuality"), "extract normalization should keep crafted quality nil for non-crafted rows")
assert.equal("True", read_item_field_is_null(normalizedOutputPath, 132514, "craftedQualityIcon"), "extract normalization should keep crafted quality icon nil for non-crafted rows")
assert.equal("3", read_item_field(normalizedOutputPath, 242273, "quality"), "extract normalization should allow hotfix rows to override base quality")
assert.equal("Rare", read_item_field(normalizedOutputPath, 242273, "qualityName"), "extract normalization should keep the hotfix-adjusted quality name")
assert.equal("Arcanoweave Spellthread", read_item_field(normalizedOutputPath, 240154, "name"), "extract normalization should include newly introduced hotfix rows")
assert.equal("5", read_item_field(normalizedOutputPath, 240154, "craftedQuality"), "extract normalization should preserve crafted quality tiers when present in the local source")
assert.equal("Professions-ChatIcon-Quality-Tier5", read_item_field(normalizedOutputPath, 240154, "craftedQualityIcon"), "extract normalization should derive the crafted quality icon from the tier")
assert.equal("1", read_item_field(normalizedOutputPath, 241326, "craftedQuality"), "extract normalization should derive the lower crafted tier for duplicate-name modern crafted variants")
assert.equal("Professions-ChatIcon-Quality-Tier1", read_item_field(normalizedOutputPath, 241326, "craftedQualityIcon"), "extract normalization should derive the lower crafted tier icon for duplicate-name modern crafted variants")
assert.equal("2", read_item_field(normalizedOutputPath, 241327, "craftedQuality"), "extract normalization should derive the higher crafted tier for two-rank duplicate-name variants")
assert.equal("Professions-ChatIcon-Quality-Tier2", read_item_field(normalizedOutputPath, 241327, "craftedQualityIcon"), "extract normalization should derive the higher crafted tier icon for two-rank duplicate-name variants")
assert.equal("1", read_item_field(normalizedOutputPath, 212281, "craftedQuality"), "extract normalization should derive the first crafted tier for three-rank duplicate-name variants")
assert.equal("2", read_item_field(normalizedOutputPath, 212282, "craftedQuality"), "extract normalization should derive the middle crafted tier for three-rank duplicate-name variants")
assert.equal("3", read_item_field(normalizedOutputPath, 212283, "craftedQuality"), "extract normalization should derive the top crafted tier for three-rank duplicate-name variants")
assert.equal("True", read_item_field_is_null(normalizedOutputPath, 555001, "craftedQuality"), "extract normalization should not assign crafted tiers to duplicate-name groups that fail the modern crafted-variant heuristic")
assert.equal("True", read_item_field_is_null(normalizedOutputPath, 555002, "craftedQuality"), "extract normalization should leave non-crafted duplicate-name groups without derived crafted tiers")
assert.equal("8", read_item_field(normalizedOutputPath, 240154, "classID"), "extract normalization should preserve class ids from the local extraction source")
assert.equal("0", read_item_field(normalizedOutputPath, 240154, "subclassID"), "extract normalization should preserve subclass ids from the local extraction source")
assert.equal("18", read_item_field(normalizedOutputPath, 250001, "inventoryType"), "extract normalization should preserve inventory type metadata when present")
assert.equal("confirmed", read_item_field(normalizedOutputPath, 240154, "status"), "extract normalization should stamp confirmed rows")
assert.equal("local_client_item_db2", read_item_field(normalizedOutputPath, 240154, "source"), "extract normalization should stamp the extraction source")
assert.equal("Retail", read_item_field(normalizedOutputPath, 240154, "target"), "extract normalization should stamp the selected target")
assert.equal("11.2.7.63796", read_item_field(normalizedOutputPath, 240154, "build"), "extract normalization should stamp the selected build")
assert.equal("en_US", read_item_field(normalizedOutputPath, 240154, "locale"), "extract normalization should stamp the locale")
assert.truthy(read_item_field(normalizedOutputPath, 240154, "lastVerifiedAt") ~= "", "extract normalization should stamp a verification timestamp")
assert.equal("completed", read_json_query(extractProgressPath, "$data.status"), "extract command should leave a completed progress state after a successful fresh run")
assert.equal("extraction", read_json_query(extractProgressPath, "$data.phase"), "extract command should track extraction as the active phase in progress state")
assert.equal("Full", read_json_query(extractProgressPath, "$data.catalogProfile"), "extract command should persist the selected catalog profile in progress state")
assert.equal("999999", read_json_query(extractProgressPath, "$data.lastProcessedItemID"), "extract command should persist the last processed source item id in progress state")
assert.equal("16", read_json_query(extractProgressPath, "$data.normalizedCountWritten"), "extract command should persist the normalized rows written in progress state")

local procurementOutputPath = join_path(outputDir, "procurement-normalized-items.json")
local procurementProgressPath = join_path(progressDir, "procurement-progress.json")
local procurementPartialRowsPath = join_path(progressDir, "procurement-progress.partial.jsonl")
local procurementExtract = run_extract({
    "-Target", "Retail",
    "-Mode", "Fresh",
    "-CatalogProfile", "ProcurementCurrentExpansion",
    "-Locale", "en_US",
    "-FixturePath", powershell_argument(extractFixturePath),
    "-OutputPath", powershell_argument(procurementOutputPath),
    "-ProgressPath", powershell_argument(procurementProgressPath),
    "-PartialRowsPath", powershell_argument(procurementPartialRowsPath),
})
assert.truthy(procurementExtract.success, "extract command should support the procurement current-expansion profile")
assert.equal("ProcurementCurrentExpansion", json_string_field(procurementExtract.output, "catalogProfile"), "procurement extraction should report the selected catalog profile")
assert.equal(8, json_number_field(procurementExtract.output, "normalizedCount"), "procurement extraction should keep only current-expansion procurement categories")
assert.equal("8", read_json_query(procurementOutputPath, "$data.items.Count"), "procurement extraction should write the reduced current-expansion procurement item set")
assert.equal("1", read_item_field(procurementOutputPath, 241326, "craftedQuality"), "procurement extraction should retain duplicate-name crafted tier variants in the reduced catalog")
assert.equal("2", read_item_field(procurementOutputPath, 241327, "craftedQuality"), "procurement extraction should retain the higher duplicate-name crafted tier variant in the reduced catalog")
assert.equal("1", read_item_field(procurementOutputPath, 243733, "craftedQuality"), "procurement extraction should retain lower-tier current-expansion item enhancements")
assert.equal("2", read_item_field(procurementOutputPath, 243734, "craftedQuality"), "procurement extraction should retain higher-tier current-expansion item enhancements")
assert.equal("", read_item_field(procurementOutputPath, 212281, "name"), "procurement extraction should exclude old-expansion consumables from the shipped catalog")
assert.equal("", read_item_field(procurementOutputPath, 250004, "name"), "procurement extraction should exclude non-procurement current-expansion weapon rows from the shipped catalog")

local resumeOutputPath = join_path(outputDir, "resume-normalized-items.json")
local resumeOutputAbsolute = absolute_path(resumeOutputPath)
local resumeProgressPath = join_path(progressDir, "resume-progress.json")
local resumePartialRowsPath = join_path(progressDir, "resume-progress.partial.jsonl")
write_text_file(resumePartialRowsPath, [[
{"itemID":132514,"name":"Auto-Hammer","quality":2,"qualityName":"Uncommon","craftedQuality":null,"craftedQualityIcon":null,"status":"confirmed","source":"local_client_item_db2","target":"Retail","build":"11.2.7.63796","locale":"en_US","lastVerifiedAt":"2026-05-14T00:00:00.000Z"}
]])
write_text_file(resumeProgressPath, [[
{
  "target": "Retail",
  "catalogProfile": "Full",
  "mode": "Fresh",
  "status": "failed",
  "phase": "extraction",
  "build": "11.2.7.63796",
  "locale": "en_US",
  "outputPath": "]] .. normalize_path(absolute_path(resumeOutputPath)):gsub("\\", "\\\\") .. [[",
  "partialRowsPath": "]] .. normalize_path(absolute_path(resumePartialRowsPath)):gsub("\\", "\\\\") .. [[",
  "startedAt": "2026-05-14T00:00:00.000Z",
  "updatedAt": "2026-05-14T00:05:00.000Z",
  "completedAt": null,
  "resumeSupported": true,
  "rawRowCountSeen": 4,
  "normalizedCountWritten": 1,
  "lastProcessedItemID": 132514,
  "lastProcessedIndex": 1,
  "highestSeenItemID": 240154,
  "failureClass": "extraction",
  "failureMessage": "simulated interruption"
}
]])

local resumedExtract = run_extract({
    "-Target", "Retail",
    "-Mode", "Resume",
    "-CatalogProfile", "Full",
    "-Locale", "en_US",
    "-FixturePath", powershell_argument(extractFixturePath),
    "-OutputPath", powershell_argument(resumeOutputPath),
    "-ProgressPath", powershell_argument(resumeProgressPath),
    "-PartialRowsPath", powershell_argument(resumePartialRowsPath),
})
assert.truthy(resumedExtract.success, "extract command should resume successfully from a prior failed progress boundary")
assert.equal("Resume", json_string_field(resumedExtract.output, "mode"), "resume runs should report resume mode")
assert.equal("Full", json_string_field(resumedExtract.output, "catalogProfile"), "resume runs should preserve the selected catalog profile")
assert.equal(resumeOutputAbsolute, json_string_field(resumedExtract.output, "normalizedRowsPath"), "resume runs should rebuild the final normalized output at the requested path")
assert.equal(999999, json_number_field(resumedExtract.output, "lastProcessedItemID"), "resume runs should advance to the final processed source item id")
assert.equal(16, json_number_field(resumedExtract.output, "normalizedCountWritten"), "resume runs should report the combined written-row count")
assert.equal("16", read_json_query(resumeOutputPath, "$data.items.Count"), "resume runs should finalize the combined normalized output")
assert.equal("Auto-Hammer", read_item_field(resumeOutputPath, 132514, "name"), "resume runs should preserve rows written before the interruption")
assert.equal("Arcanoweave Spellthread", read_item_field(resumeOutputPath, 240154, "name"), "resume runs should append rows after the saved item boundary")
assert.equal("completed", read_json_query(resumeProgressPath, "$data.status"), "resume runs should promote the progress state to completed")

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
  "itemCount": 1,
  "unresolvedCount": 1,
  "items": [
    {
      "itemID": 7007,
      "name": "Algari Mana Oil",
      "quality": null,
      "qualityName": null,
      "craftedQuality": null,
      "craftedQualityIcon": null,
      "status": "learned",
      "lastVerifiedAt": null,
      "unresolved": false,
      "source": "starter_seed"
    }
  ]
}
]])

local refreshOutputPath = join_path(outputDir, "refresh-normalized-items.json")
local refreshOutputAbsolute = absolute_path(refreshOutputPath)
local refreshLuaPath = join_path(outputDir, "refresh-item-data.lua")
local refreshProgressPath = join_path(progressDir, "refresh-progress.json")
local refreshPartialRowsPath = join_path(progressDir, "refresh-progress.partial.jsonl")
local refresh = run_refresh({
    "-Target", "Retail",
    "-Fresh",
    "-CatalogProfile", "Full",
    "-WoWRoot", powershell_argument(wowFixtureRoot),
    "-ExtractionFixturePath", powershell_argument(extractFixturePath),
    "-ExtractionOutputPath", powershell_argument(refreshOutputPath),
    "-ManifestPath", powershell_argument(refreshManifestPath),
    "-OutputLuaPath", powershell_argument(refreshLuaPath),
    "-ProgressPath", powershell_argument(refreshProgressPath),
    "-PartialRowsPath", powershell_argument(refreshPartialRowsPath),
})

assert.truthy(refresh.success, "refresh command should succeed when extraction normalization succeeds")
assert.equal(0, refresh.exitCode, "refresh command should exit 0 when the current phase reaches the rebuilt-addon boundary")
assert.equal("ready", json_string_field(refresh.output, "status"), "refresh command should preserve the ready status for the rebuilt-addon boundary")
assert.equal("Retail", json_string_field(refresh.output, "target"), "refresh command should report the resolved target")
assert.equal("Full", json_string_field(refresh.output, "catalogProfile"), "refresh command should surface the selected catalog profile")
assert.equal("11.2.7.63796", json_string_field(refresh.output, "build"), "refresh command should surface the extracted build")
assert.equal("en_US", json_string_field(refresh.output, "locale"), "refresh command should surface the extracted locale")
assert.equal(refreshOutputAbsolute, json_string_field(refresh.output, "normalizedRowsPath"), "refresh command should report the normalized extraction output path")
assert.equal(16, json_number_field(refresh.output, "normalizedCount"), "refresh command should surface the normalized row count")
assert.equal("addon-rebuilt", json_string_field(refresh.output, "nextStep"), "refresh command should report that extraction continued through merge and generated addon rebuild")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_"), json_string_field(refresh.output, "clientDirectory"), "refresh command should continue to report the validated client directory")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_", "Data"), json_string_field(refresh.output, "dataDirectory"), "refresh command should continue to report the validated data directory")
assert.equal(join_path(wowFixtureRootAbsolute, "_retail_", "Data", "en_US"), json_string_field(refresh.output, "localeDirectory"), "refresh command should continue to report the validated locale directory")
assert.equal("16", read_json_query(refreshOutputPath, "$data.items.Count"), "refresh command should persist the normalized rows for the next pipeline phase")

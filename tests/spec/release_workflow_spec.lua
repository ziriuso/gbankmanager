local assert = require("tests.helpers.assert")

local function read_file(path)
    local handle, err = io.open(path, "rb")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

local workflow = read_file(".github/workflows/release-curseforge.yml")
local buildScript = read_file("tools/release/Build-CurseForgePackage.ps1")
local publishScript = read_file("tools/release/Publish-CurseForgePackage.ps1")
local releaseDoc = read_file("docs/curseforge-release-workflow.md")

assert.truthy(string.find(workflow, "tags:", 1, true) ~= nil, "release workflow should trigger from git tags")
assert.truthy(string.find(workflow, "v*", 1, true) ~= nil, "release workflow should listen for version tags")
assert.truthy(string.find(workflow, ".\\tools\\lua\\lua.exe .\\tests\\run_all.lua", 1, true) ~= nil, "release workflow should run the full Lua suite before packaging")
assert.truthy(string.find(workflow, "CF_API_TOKEN", 1, true) ~= nil, "release workflow should read the CurseForge API token from a GitHub secret name")
assert.truthy(string.find(workflow, "CF_PROJECT_ID", 1, true) ~= nil, "release workflow should read the CurseForge project id from a GitHub variable or secret name")
assert.truthy(string.find(workflow, "softprops/action-gh-release", 1, true) ~= nil, "release workflow should attach the built zip to the GitHub release")
assert.truthy(string.find(workflow, "Build-CurseForgePackage.ps1", 1, true) ~= nil, "release workflow should call the package build script")
assert.truthy(string.find(workflow, "Publish-CurseForgePackage.ps1", 1, true) ~= nil, "release workflow should call the CurseForge publish script")

assert.truthy(string.find(buildScript, "GBankManager", 1, true) ~= nil, "build script should package the main addon folder")
assert.truthy(string.find(buildScript, "GBankManager_ItemData", 1, true) ~= nil, "build script should package the dependency addon folder")
assert.truthy(string.find(buildScript, "alpha", 1, true) ~= nil, "build script should recognize alpha tags")
assert.truthy(string.find(buildScript, "beta", 1, true) ~= nil, "build script should recognize beta tags")
assert.truthy(string.find(buildScript, "release", 1, true) ~= nil, "build script should recognize release tags")

assert.truthy(string.find(publishScript, "upload-file", 1, true) ~= nil, "publish script should upload files to the CurseForge upload API")
assert.truthy(string.find(publishScript, "gameVersions", 1, true) ~= nil, "publish script should submit CurseForge game version ids")
assert.truthy(string.find(publishScript, "[object[]]@($versionIds)", 1, true) ~= nil, "publish script should force game version ids to serialize as an array even when only one id is present")
assert.truthy(string.find(publishScript, "releaseType", 1, true) ~= nil, "publish script should submit the derived CurseForge release type")

assert.truthy(string.find(releaseDoc, "CF_API_TOKEN", 1, true) ~= nil, "release workflow doc should explain which GitHub secret stores the CurseForge token")
assert.truthy(string.find(releaseDoc, "CF_PROJECT_ID", 1, true) ~= nil, "release workflow doc should explain which GitHub variable stores the CurseForge project id")
assert.truthy(string.find(releaseDoc, "rotate", 1, true) ~= nil, "release workflow doc should remind maintainers to rotate exposed CurseForge tokens")
assert.truthy(string.find(releaseDoc, "GitHub Release", 1, true) ~= nil, "release workflow doc should explain the GitHub release attachment behavior")

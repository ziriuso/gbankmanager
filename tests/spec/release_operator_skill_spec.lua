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

local skill = read_file("docs/skills/gbankmanager-release-operator/SKILL.md")
local releaseDoc = read_file("docs/curseforge-release-workflow.md")
local readme = read_file("README.md")
local handoff = read_file("docs/superpowers/handoffs/latest-handoff.md")

assert.truthy(string.find(skill, "Use when handling a GBankManager alpha, beta, or release publish", 1, true) ~= nil, "release operator skill should describe its release triggers")
assert.truthy(string.find(skill, ".\\tools\\lua\\lua.exe .\\tests\\run_all.lua", 1, true) ~= nil, "release operator skill should require the full Lua suite")
assert.truthy(string.find(skill, "gh run view <run-id> --log-failed", 1, true) ~= nil, "release operator skill should document failed run log inspection")
assert.truthy(string.find(skill, "Do not reuse a failed tag for a new payload.", 1, true) ~= nil, "release operator skill should require a fresh tag after failed publishes")
assert.truthy(string.find(skill, "forever-v", 1, true) ~= nil, "release operator skill should give Forever its own tag line")
assert.truthy(string.find(skill, "Do not merge Forever into master", 1, true) ~= nil, "release operator skill should keep the Forever branch out of the Retail release line")
assert.truthy(string.find(skill, "GBankManager/GBankManager.toc", 1, true) ~= nil, "release operator skill should mention TOC version confirmation")
assert.truthy(string.find(skill, ".worktrees\\gbankmanager-v1", 1, true) == nil, "release operator skill should not require an obsolete machine-local worktree")

local skillBranchPushPosition = string.find(skill, "git push -u origin HEAD", 1, true)
local skillPrCreatePosition = string.find(skill, "gh pr create", 1, true)
local skillPrMergePosition = string.find(skill, "gh pr merge", 1, true)
local skillDefaultBranchRefreshPosition = string.find(skill, "git fetch origin master", 1, true)
local skillTagPosition = string.find(skill, "git tag <tag> origin/master", 1, true)

assert.truthy(skillBranchPushPosition ~= nil, "release operator skill should push the release branch before integration")
assert.truthy(skillPrCreatePosition ~= nil, "release operator skill should create a pull request before tagging")
assert.truthy(skillPrMergePosition ~= nil, "release operator skill should merge the pull request before tagging")
assert.truthy(skillDefaultBranchRefreshPosition ~= nil, "release operator skill should refresh the remote default branch after merge")
assert.truthy(skillTagPosition ~= nil, "release operator skill should tag the merged default-branch commit")
assert.truthy(
    skillBranchPushPosition < skillPrCreatePosition
        and skillPrCreatePosition < skillPrMergePosition
        and skillPrMergePosition < skillDefaultBranchRefreshPosition
        and skillDefaultBranchRefreshPosition < skillTagPosition,
    "release operator skill should order branch push, PR merge, default-branch refresh, and tagging safely"
)

assert.truthy(string.find(releaseDoc, "docs/skills/gbankmanager-release-operator/SKILL.md", 1, true) ~= nil, "release workflow doc should point to the repo-local release operator skill")
assert.truthy(string.find(readme, "gbankmanager-release-operator", 1, true) ~= nil, "README should mention the repo-local release operator skill")
assert.truthy(string.find(handoff, "gbankmanager-release-operator", 1, true) ~= nil, "handoff should mention the repo-local release operator skill")

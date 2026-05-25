package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local ns = env.ns
local slash = env.slash
local store = ns.modules.store
local inGameUnit = ns.modules.inGameUnit

assert.truthy(type(inGameUnit) == "table", "in-game unit module should load from the addon toc")
assert.truthy(type(inGameUnit.Run) == "function", "in-game unit module should expose an explicit runner")

_G.DEFAULT_CHAT_FRAME.messages = {}

local db = store.CreateFreshDatabase("Guild Testers")
_G.GBankManagerDB = db
ns.state.db = db

local summary = slash.command("test unit")

assert.truthy(type(summary) == "string" and string.find(summary, "PASS", 1, true) ~= nil, "slash test unit should return a pass summary when the in-game unit checks succeed")
assert.equal(summary, db.testing.inGameUnit.summary, "in-game unit runs should persist the same summary they return to the caller")
assert.equal("PASS", db.testing.inGameUnit.status, "in-game unit runs should persist a pass/fail status")
assert.truthy(type(db.testing.inGameUnit.results) == "table" and #db.testing.inGameUnit.results >= 8, "in-game unit runs should persist the expanded individual in-game unit check results")
assert.truthy(#_G.DEFAULT_CHAT_FRAME.messages >= 2, "in-game unit runs should emit a chat-visible summary")

local checksById = {}
for _, result in ipairs(db.testing.inGameUnit.results or {}) do
    checksById[result.id] = result
end

assert.truthy(checksById.auth_policy_round_trip ~= nil, "in-game unit lane should cover auth policy round-tripping")
assert.truthy(checksById.request_contracts ~= nil, "in-game unit lane should cover request workflow invariants")
assert.truthy(checksById.crafted_quality_normalization ~= nil, "in-game unit lane should cover crafted-quality normalization")
assert.truthy(checksById.dashboard_withdrawals ~= nil, "in-game unit lane should cover dashboard withdrawal-driven ranking")
assert.truthy(checksById.sync_sender_guard ~= nil, "in-game unit lane should cover sync sender validation")
assert.truthy(checksById.blacklist_normalization ~= nil, "in-game unit lane should cover blacklist normalization behavior")
assert.truthy(checksById.request_admin_queue ~= nil, "in-game unit lane should cover officer queue prioritization")
assert.truthy(checksById.minimum_orphan_ordering ~= nil, "in-game unit lane should cover unresolved minimum row ordering")

local originalCraftedQuality = ns.modules.craftedQuality
ns.modules.craftedQuality = nil
_G.DEFAULT_CHAT_FRAME.messages = {}
local fallbackSummary = slash.command("test unit")
ns.modules.craftedQuality = originalCraftedQuality

assert.truthy(type(fallbackSummary) == "string" and string.find(fallbackSummary, "PASS", 1, true) ~= nil, "in-game unit should recover when the crafted-quality helper is missing from the module registry")
local fallbackChecksById = {}
for _, result in ipairs(db.testing.inGameUnit.results or {}) do
    fallbackChecksById[result.id] = result
end
assert.truthy(fallbackChecksById.crafted_quality_normalization ~= nil and fallbackChecksById.crafted_quality_normalization.passed == true, "crafted-quality normalization check should self-heal and still pass when the helper must be reloaded")

local originalInGameUnit = ns.modules.inGameUnit
_G.DEFAULT_CHAT_FRAME.messages = {}
ns.modules.inGameUnit = nil
local unavailable = slash.command("test unit")
ns.modules.inGameUnit = originalInGameUnit

assert.equal("unit_test_unavailable", unavailable, "slash test unit should return an explicit unavailable code when the in-game unit module is missing")
assert.truthy(#_G.DEFAULT_CHAT_FRAME.messages >= 1, "slash test unit should emit visible chat feedback when the in-game unit module is unavailable")
assert.truthy(string.find(_G.DEFAULT_CHAT_FRAME.messages[1] or "", "unavailable", 1, true) ~= nil, "missing in-game unit feedback should explain that the unit test command is unavailable")

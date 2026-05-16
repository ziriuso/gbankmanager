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
local liveSmoke = ns.modules.liveSmoke
local itemCatalog = ns.modules.itemCatalog

assert.truthy(type(liveSmoke) == "table", "live smoke module should load from the addon toc")
assert.truthy(type(liveSmoke.Run) == "function", "live smoke module should expose an explicit runner")
assert.truthy(type(itemCatalog) == "table", "live smoke spec should load the shared item catalog module")
assert.truthy(type(itemCatalog.GetBundledSearchPayload) == "function", "live smoke spec should expose bundled search payload access")
assert.truthy(type(itemCatalog.ResolveIndexedQuery) == "function", "live smoke spec should expose indexed bundled search resolution")

local bundledPayload = itemCatalog.GetBundledSearchPayload()
assert.truthy(itemCatalog.IsBundledSearchReady(bundledPayload), "live smoke spec should start from a ready bundled indexed-search payload")
assert.truthy(#(itemCatalog.ResolveIndexedQuery(bundledPayload, "flask").matches or {}) >= 4, "bundled indexed search should surface a broader flask family than the broken two-result regression")
assert.truthy(#(itemCatalog.ResolveIndexedQuery(bundledPayload, "flask of").matches or {}) >= 4, "bundled indexed search should keep broad token queries like flask of populated")
assert.truthy(#(itemCatalog.ResolveIndexedQuery(bundledPayload, "flask magister").matches or {}) >= 2, "bundled indexed search should keep both Magisters quality variants available")
assert.truthy(#(itemCatalog.ResolveIndexedQuery(bundledPayload, "flask of the shat").matches or {}) >= 2, "bundled indexed search should keep the Shattered Sun family available when narrowed by a stable partial token")

_G.DEFAULT_CHAT_FRAME.messages = {}

local db = store.CreateFreshDatabase("Guild Testers")
_G.GBankManagerDB = db
ns.state.db = db

local summary = slash.command("test smoke")

assert.truthy(type(summary) == "string" and string.find(summary, "PASS", 1, true) ~= nil, "slash test smoke should return a pass summary when the smoke checks succeed")
assert.equal(summary, db.testing.liveSmoke.summary, "live smoke runs should persist the same summary they return to the caller")
assert.equal("PASS", db.testing.liveSmoke.status, "live smoke runs should persist a pass/fail status")
assert.truthy(type(db.testing.liveSmoke.results) == "table" and #db.testing.liveSmoke.results >= 5, "live smoke runs should persist the individual smoke check results")
assert.truthy(#_G.DEFAULT_CHAT_FRAME.messages >= 2, "live smoke runs should emit a chat-visible summary")

local checksById = {}
for _, result in ipairs(db.testing.liveSmoke.results or {}) do
    checksById[result.id] = result
end

assert.truthy(checksById.shell_open_close ~= nil, "live smoke should cover shell open/close behavior")
assert.truthy(checksById.options_render_scroll ~= nil, "live smoke should cover options rendering and scroll reachability")
assert.truthy(checksById.opacity_controls ~= nil, "live smoke should cover in-client opacity controls")
assert.truthy(checksById.request_access_modes ~= nil, "live smoke should cover request-only versus full-shell access")
assert.truthy(checksById.request_sync_contract ~= nil, "live smoke should cover the request sync contract invariants")
assert.truthy(checksById.minimums_render ~= nil, "live smoke should cover minimums rendering flows")
assert.truthy(checksById.request_selection_gating ~= nil, "live smoke should cover confirmed-selection gating for request creation")
assert.truthy(checksById.scan_access_gating ~= nil, "live smoke should cover scan/officer gating")

local originalLiveSmoke = ns.modules.liveSmoke
_G.DEFAULT_CHAT_FRAME.messages = {}
ns.modules.liveSmoke = nil
local unavailable = slash.command("test smoke")
ns.modules.liveSmoke = originalLiveSmoke

assert.equal("smoke_test_unavailable", unavailable, "slash test smoke should return an explicit unavailable code when the live smoke module is missing")
assert.truthy(#_G.DEFAULT_CHAT_FRAME.messages >= 1, "slash test smoke should emit visible chat feedback when the live smoke module is unavailable")
assert.truthy(string.find(_G.DEFAULT_CHAT_FRAME.messages[1] or "", "unavailable", 1, true) ~= nil, "missing live smoke feedback should explain that the smoke command is unavailable")

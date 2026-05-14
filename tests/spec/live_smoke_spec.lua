local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local ns = env.ns
local slash = env.slash
local store = ns.modules.store
local liveSmoke = ns.modules.liveSmoke

assert.truthy(type(liveSmoke) == "table", "live smoke module should load from the addon toc")
assert.truthy(type(liveSmoke.Run) == "function", "live smoke module should expose an explicit runner")

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
assert.truthy(checksById.minimums_render ~= nil, "live smoke should cover minimums rendering flows")
assert.truthy(checksById.scan_access_gating ~= nil, "live smoke should cover scan/officer gating")

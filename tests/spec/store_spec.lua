local assert = require("tests.helpers.assert")
local ns = dofile("GBankManager/Core/Namespace.lua")

assert.equal("GBankManager", ns.addonName, "namespace should expose addon name")
assert.truthy(type(ns.modules) == "table", "namespace should expose module table")

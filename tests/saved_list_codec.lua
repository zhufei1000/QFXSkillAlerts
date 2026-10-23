local root = assert(arg[1], "Pass the complete addon source parent") .. "/"
unpack = unpack or table.unpack
assert(loadfile(root .. "QFXSkillAlerts/Ace3/LibStub/LibStub.lua"))()
assert(loadfile(root .. "QFXSkillAlerts_Config/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua"))()
assert(loadfile(root .. "QFXSkillAlerts_Config/Libs/LibDeflate/LibDeflate.lua"))()
QFXSkillAlertsNS = {}
assert(loadfile(root .. "QFXSkillAlerts_Config/Core/ImportCodec.lua"))()
local codec = QFXSkillAlertsNS.ImportCodec
local payload = { type = "full", savedListOrder = {
    loaded = { "0:0:3", "group:8:62:a", "0:0:1" }, unloaded = { "0:0:2" },
    manual = { loaded = true, unloaded = false },
} }
local encoded = codec:Encode(payload)
assert(encoded:match("^!QFXSA:1!"))
local decoded = assert(codec:Decode(encoded))
assert(decoded.savedListOrder.manual.loaded == true and decoded.savedListOrder.manual.unloaded == false)
assert(table.concat(decoded.savedListOrder.loaded, ",") == table.concat(payload.savedListOrder.loaded, ","))
assert(decoded.savedListOrder.unloaded[1] == "0:0:2")
print("PASS: config-only serializer/compression libraries preserve manual sorting metadata and saved positions through export/import encoding")

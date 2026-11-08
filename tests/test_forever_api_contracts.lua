local function equal(actual, expected, message)
    assert(actual == expected, (message or "values differ")..": "..tostring(actual).." ~= "..tostring(expected))
end
function wipe(t) for key in pairs(t) do t[key] = nil end return t end
function GetBuildInfo() return "1.60.1", "70790", "", 16001 end
function UnitClass() return "Shaman", "SHAMAN", 7 end
function IsPlayerSpell() return false end
QFXSkillAlertsNS = {Core = {}, Constants = {}, Utils = {}}
local NS = QFXSkillAlertsNS
local group = 1
C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 1489, "Shaman" end,
    GetNumSpecializationsForClassID = function() return 1 end,
    GetActiveSpecGroup = function() return group end,
    GetCombatConfigIDForSpecGroup = function(value) return 100 + value end,
}
function GetSpecializationInfoForClassID(classID, index)
    equal(classID, 7); equal(index, 1)
    return 1489, "Shaman", "", 123
end
dofile("QFXSkillAlerts/Core/Compat.lua")
dofile("QFXSkillAlerts/Core/Scope.lua")
dofile("QFXSkillAlerts/Core/CDMVoiceService.lua")
local compat, scope, service = NS.Core.Compat, NS.Core.Scope, NS.Core.CDMVoiceService
equal(compat:GetCurrentSpecID(), 1489)
local classID, specID = scope:GetCurrentClassSpec()
equal(classID, 7); equal(specID, 1489)
classID, specID = service:GetCurrentClassSpec()
equal(classID, 7); equal(specID, 1489)
equal(scope:ResolveSpecName(7, 1489), "Shaman")
equal(compat:GetSpecOptions(7)[1].specID, 1489)
GetSpecialization = function() error("Namespaced API must take priority") end
GetSpecializationInfo = GetSpecialization
equal(compat:GetCurrentSpecID(), 1489)

C_ClassTalents = {GetActiveConfigID = function() return nil end}
local selected = {[101] = 12345, [102] = 54321}
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {10}} end,
    GetTreeNodes = function() return {20} end,
    GetNodeInfo = function() return {activeRank = 1, activeEntry = {entryID = 30}} end,
    GetEntryInfo = function() return {definitionID = 40} end,
    GetDefinitionInfo = function() return {spellID = selected[100 + group]} end,
}
dofile("QFXSkillAlerts/Core/Resolver.lua")
local resolver = NS.Core.Resolver
equal(resolver:GetActiveTalentConfigID(), 101, "active talent group fallback")
assert(resolver:IsTalentSelectedCached(12345))
assert(not resolver:IsTalentSelectedCached(54321), "unselected talent must stay unselected")
dofile("QFXSkillAlerts/Core/RuntimeConfigBuilder.lua")
local entries = {{spellId = 2825, baseCD = 120, cdMode = "fixed", checkTalent = true,
    talentId = 54321, talentCD = 60, loadTalentEnabled = true, loadTalentId = 54321}}
local builder = NS.Core.RuntimeConfigBuilder
builder:Configure({
    getCurrentClassSpec = function() return scope:GetCurrentClassSpec() end,
    getStoredEntryMap = function(class) return class == 0 and entries or {} end,
    getOrderedEntryIndices = function(map) return map == entries and {1} or {} end,
    getEntry = function(map, index) return map[index] end,
    isTalentSelected = function(id) return resolver:IsTalentSelectedCached(id) end,
})
local mapping, runtime = {}, {}
builder:Rebuild(mapping, runtime)
equal(next(runtime), nil, "unselected load talent blocks the real builder")
entries[1].loadTalentEnabled = false
builder:Rebuild(mapping, runtime)
equal(runtime["spell:2825"].baseCD, 120, "unselected cooldown talent keeps base CD")
group = 2
resolver:InvalidateTalentCache()
assert(resolver:IsTalentSelectedCached(54321))
assert(not resolver:IsTalentSelectedCached(12345))
builder:Rebuild(mapping, runtime)
equal(runtime["spell:2825"].baseCD, 60, "selected cooldown talent applies reduced CD")
local readConfig = C_Traits.GetConfigInfo
C_Traits.GetConfigInfo = function() return nil end
resolver:InvalidateTalentCache()
assert(not resolver:IsTalentSelectedCached(54321), "unavailable data must not enable a talent")
C_Traits.GetConfigInfo = readConfig

Enum = {CooldownViewerAlertEventType = {Available = 1, ChargeGained = 4}}
QFXSkillAlertsDB = {}
dofile("QFXSkillAlerts/Core/CDMVoicePresetStore.lua")
local store = NS.Core.CDMVoicePresetStore
local key = assert(store:SaveAppliedRecord({classID = 7, specID = 0, category = "essential",
    spellID = 2825, eventKey = "AVAILABLE", voiceName = "Old voice"}))
local records = store:GetEffectiveRecords(7, 1489)
equal(#records, 1, "legacy all-specs voices must remain active")
equal(records[1].specID, 0, "reading must not migrate or rewrite the saved scope")
assert(store:HasEffectiveRecord(7, 1489, key))
local record, recordKey = store:GetRecordForAlert(7, 1489, "essential", 2825, 1)
equal(recordKey, key); equal(record.specID, 0)
store:SetPendingRemoval(records[1])
assert(store:GetPendingRemovals(7, 1489)[key], "legacy removal plans remain visible")
local mutation = assert(store:RemoveOrDisableRecord(7, 1489, key))
equal(mutation.specID, 0)
equal(#store:GetEffectiveRecords(7, 1489), 0, "remove must edit the inherited source")
assert(store:RestoreRecordMutation(mutation))
equal(#store:GetEffectiveRecords(7, 1489), 1)
store:SaveAppliedRecord({classID = 7, specID = 1489, category = "essential",
    spellID = 2825, eventKey = "AVAILABLE", voiceName = "Current voice"})
records = store:GetEffectiveRecords(7, 1489)
equal(#records, 1, "current specialization overrides matching all-specs record")
equal(records[1].voiceName, "Current voice")
equal(store:GetPendingRemovals(7, 1489)[key], nil,
    "a current-scope override must not inherit stale all-specs removals")
QFXSkillAlertsDB.cdmVoiceProfiles[7][1489][key].enabled = false
equal(#store:GetEffectiveRecords(7, 1489), 0, "disabled specific record must mask inherited voice")

print("PASS: Forever namespace APIs, Trait selection/group fallback, actual runtime builder and legacy scopes")

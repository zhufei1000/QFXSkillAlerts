local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

function wipe(t) for key in pairs(t) do t[key] = nil end return t end

-- Forever 1.60.1 reports interface 16001 while early builds may still expose
-- Mainline (1) as WOW_PROJECT_ID. The interface range must win.
function GetBuildInfo()
    return "1.60.1", "70790", "Nov 5 2026", 16001
end
WOW_PROJECT_ID = 1
WOW_PROJECT_MAINLINE = 1

function GetSpecialization()
    return nil
end
function GetSpecializationInfo()
    return nil
end

QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        ALL_CLASSES_ID = 0,
        ALL_SPECS_ID = 0,
        ALL_RACES_ID = 0,
        MODE_SOUND = "sound",
    },
    L = function(key) return key end,
}

dofile("QFXSkillAlerts/Core/Compat.lua")
local Compat = QFXSkillAlertsNS.Core.Compat
Assert(Compat:IsForever() == true, "interface 16001 must be detected as Forever")
Assert(Compat:IsRetail() == false, "Forever must not be treated as Retail")
Assert(Compat:SupportsMythicPlus() == false, "Forever has no Mythic+ season")
Assert(Compat:SupportsModernSpecialization() == false, "Forever has no modern specialization")
Equal(Compat:GetCurrentSpecID(), 0, "missing specialization must normalize to all-specs 0")
Assert(Compat:IsValidSpecScope(0) == true, "Forever must accept all-specs 0")
Assert(Compat:IsValidSpecScope(71) == true, "positive spec scopes must stay valid")
GetSpecialization, GetSpecializationInfo = nil, nil
function UnitClass() return "Shaman", "SHAMAN", 7 end
dofile("QFXSkillAlerts/Core/Scope.lua")
local classID, specID = QFXSkillAlertsNS.Core.Scope:GetCurrentClassSpec()
Equal(classID, 7, "missing specialization APIs must retain the player class")
Equal(specID, 0, "missing specialization APIs must use all-specs scope")
dofile("QFXSkillAlerts/Core/CDMVoiceService.lua")
local cdmClass, cdmSpec = QFXSkillAlertsNS.Core.CDMVoiceService:GetCurrentClassSpec()
Equal(cdmClass, 7, "Forever CDM service must retain the player class")
Equal(cdmSpec, 0, "Forever CDM service must support the all-specs scope")
dofile("QFXSkillAlerts/Core/Resolver.lua")
Assert(not QFXSkillAlertsNS.Core.Resolver:IsTalentSelectedCached(12345),
    "unknown talent data must not be treated as a selected talent")
Assert(Compat:SupportsTalentLoadConditions(), "Forever still supports Trait talent conditions")

Enum = {
    CooldownViewerAlertEventType = {
        Available = 1,
        PandemicTime = 2,
        OnCooldown = 3,
        ChargeGained = 4,
        OnAuraApplied = 5,
        OnAuraRemoved = 6,
    },
}
QFXSkillAlertsDB = {}
dofile("QFXSkillAlerts/Core/CDMVoicePresetStore.lua")
local Store = QFXSkillAlertsNS.Core.CDMVoicePresetStore
local foreverRecord = Store:SanitizeRecord({
    classID = 7,
    specID = 0,
    category = "essential",
    spellID = 2825,
    eventKey = "AVAILABLE",
    eventTypeHint = 1,
    voiceName = "Test",
})
Assert(foreverRecord ~= nil, "Forever CDM records must accept specID 0")
Equal(foreverRecord.specID, 0, "the saved CDM record must keep the all-specs scope")
local pendingKey, pendingRecord = Store:SetPendingRemoval(foreverRecord)
Assert(pendingKey ~= nil and pendingRecord ~= nil, "Forever CDM tombstones must accept specID 0")

-- Scope 0 is the bucket every spec inherits from. While the current spec is
-- unreadable, automatic captures must skip instead of storing one spec's
-- observed data there.
local Service = QFXSkillAlertsNS.Core.CDMVoiceService
QFXSkillAlertsDB = {}
Equal(Service:CaptureCurrentSpecCatalog(true), false,
    "an unknown current spec must skip the catalog capture")
Equal(QFXSkillAlertsDB.cdmSkillCatalog, nil, "no all-specs catalog bucket may be created")
Equal(Store:CaptureCurrentSpecFromLayout(), 0,
    "an unknown current spec must skip the layout capture")
Equal(QFXSkillAlertsDB.cdmVoiceProfiles, nil, "no all-specs profile bucket may be created")
-- An explicit positive scope is still a normal write.
Assert(Service:SaveSkillCatalog(7, 1485, { { spellID = 2825, spellName = "Test" } }),
    "an explicit concrete spec must still save its catalog")
Equal(QFXSkillAlertsDB.cdmSkillCatalog[7][1485].items[1].spellID, 2825,
    "the catalog must be stored under the concrete spec")
Equal(QFXSkillAlertsDB.cdmSkillCatalog[7][0], nil, "the concrete capture must not touch scope 0")

dofile("QFXSkillAlerts/Core/EventVoice.lua")
local EventVoice = QFXSkillAlertsNS.Core.EventVoice
local optionKeys = {}
for _, option in ipairs(EventVoice:GetOptions()) do
    optionKeys[option.value] = true
end
Assert(optionKeys.combat_start == true, "normal event options must stay available")
Assert(optionKeys.mythic_plus_start == nil, "Mythic+ start must be hidden on Forever")
Assert(optionKeys.mythic_plus_complete == nil, "Mythic+ complete must be hidden on Forever")

local instanceName, instanceType = "Blackrock Depths", "party"
function GetInstanceInfo()
    return instanceName, instanceType, 0, 0, 0, 0, false, 123
end
C_DelvesUI = nil
C_ChallengeMode = nil
C_LFGList = nil

dofile("QFXSkillAlerts/Core/EventContext.lua")
local Context = QFXSkillAlertsNS.Core.EventContext
local modes = Context:GetInstanceModeOptions()
Equal(#modes, 1, "Forever must expose only the any-instance mode")
Equal(modes[1].value, "any", "the remaining mode must be any")
Assert(
    Context:MatchesEntry({
        eventLoadContexts = { dungeon = true },
        eventDungeonMode = "specific",
        eventDungeonSelectionIDs = { ["999"] = true },
    }) == true,
    "saved specific dungeon entries must fall back to any dungeon on Forever"
)
Equal(
    Context:BuildLoadConditionSignature({
        eventLoadContexts = { dungeon = true },
        eventDungeonMode = "specific",
        eventDungeonSelectionIDs = { ["999"] = true },
    }),
    "dungeon;dungeon=any",
    "specific dungeon conditions must dedupe as any on Forever"
)
instanceName, instanceType = "Molten Core", "raid"
Assert(
    Context:MatchesEntry({
        eventLoadContexts = { raid = true },
        eventRaidMode = "season",
    }) == true,
    "saved season raid entries must fall back to any raid on Forever"
)
instanceName, instanceType = "Open World", "none"
Assert(
    Context:MatchesEntry({
        eventLoadContexts = { raid = true },
        eventRaidMode = "specific",
    }) == false,
    "the original instance context must still be enforced"
)
local keptSelections = Context:FilterCurrentSeasonSelections("dungeon", { ["999"] = true })
Assert(keptSelections["999"] == true, "Forever must not filter saved specific instance IDs")
local keptNames = Context:ResolveInstanceSelectionNames(
    "dungeon",
    { ["999"] = true },
    { ["999"] = "Classic Dungeon" }
)
Equal(keptNames["999"], "Classic Dungeon", "Forever must keep saved instance names")

dofile("QFXSkillAlerts/Core/ScopeMigration.lua")
local Migration = QFXSkillAlertsNS.Core.ScopeMigration
local db = {
    specConfigs = {
        [2] = {
            [65] = {
                [1] = {
                    spellId = 31821,
                    alertClassIDs = { [0] = true },
                    alertSpecIDs = { [0] = true },
                },
            },
        },
    },
}
local changed = Migration:ApplyKnownSpecScopes(db)
Equal(changed, 0, "Forever must not apply Retail specialization migration")
Equal(db.specConfigs[2][65][1].alertClassIDs[0], true, "entry class scope must stay all classes")
Equal(db.specConfigs[2][65][1].alertSpecIDs[0], true, "entry spec scope must stay all specs")
Assert(db.knownSpecScopeMigrationVersion ~= nil, "migration version must still be stamped")

-- The all-specs scope must remain a Forever-only allowance; Retail still
-- rejects 0 so a transient no-spec state cannot write CDM records to the
-- wrong scope.
QFXSkillAlertsNS.Core.Compat = nil
GetBuildInfo = function()
    return "12.1.5", "70783", "Oct 13 2026", 120105
end
dofile("QFXSkillAlerts/Core/Compat.lua")
local RetailCompat = QFXSkillAlertsNS.Core.Compat
Assert(RetailCompat:IsForever() == false, "interface 120105 must not be treated as Forever")
Assert(RetailCompat:IsRetail() == true, "interface 120105 must be detected as Retail")
Assert(RetailCompat:IsValidSpecScope(0) == false, "Retail must reject all-specs 0 for CDM records")
Assert(
    Store:SanitizeRecord({
        classID = 7,
        specID = 0,
        category = "essential",
        spellID = 2825,
        eventKey = "AVAILABLE",
        eventTypeHint = 1,
        voiceName = "Test",
    }) == nil,
    "Retail must keep rejecting specID 0 CDM records"
)

-- Dedicated project IDs also identify Forever when a build is unavailable.
QFXSkillAlertsNS.Core.Compat = nil
GetBuildInfo = nil
WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 99, 99
dofile("QFXSkillAlerts/Core/Compat.lua")
Assert(QFXSkillAlertsNS.Core.Compat:IsForever(), "dedicated Camelot project ID must identify Forever")
Assert(not QFXSkillAlertsNS.Core.Compat:IsRetail(), "Camelot project ID must never identify Retail")

print("forever compatibility tests passed")

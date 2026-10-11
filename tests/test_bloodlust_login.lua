local function Equal(actual, expected, message)
    assert(actual == expected, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

function wipe(value) for key in pairs(value) do value[key] = nil end return value end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function(self, name, fn) self[name] = fn end }
end
function GetRealmName() return "Test Realm" end
function UnitName() return "Test Player" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function GetLocale() return "enUS" end
function GetCurrentRegion() return 1 end

dofile("QFXSkillAlerts/Ace3/LibStub/LibStub.lua")
dofile("QFXSkillAlerts/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("QFXSkillAlerts/Ace3/AceDB-3.0/AceDB-3.0.lua")
dofile("QFXSkillAlerts_Config/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua")
QFXSkillAlertsNS = { Core = {} }
dofile("QFXSkillAlerts/Core/MediaCatalog.lua")
dofile("QFXSkillAlerts/Core/Bloodlust.lua")
dofile("QFXSkillAlerts/Core/Notifier.lua")
dofile("QFXSkillAlerts/Core/Database.lua")
local NS = QFXSkillAlertsNS
local database, bloodlust, notifier = NS.Core.Database, NS.Core.Bloodlust, NS.Core.Notifier
local aceDB, serializer = LibStub("AceDB-3.0"), LibStub("AceSerializer-3.0")
local sharedPath = "Interface\\AddOns\\SharedMedia\\RaidHorn.ogg"
notifier.ShowVisualAlerts = function() return false end
local played
notifier.PlayVoiceFile = function(_, path) played = path return path ~= "" end

local function Login(saved)
    aceDB.db_registry = {}
    database.initialized, database.db = nil, nil
    QFXSkillAlertsDB = saved
    database:Initialize()
    return QFXSkillAlertsDB.bloodlustConfig
end

-- Use real AceDB defaults, logout cleanup and serialization. SavedVariables is
-- the flat active profile in this addon, so each login imports its saved fields.
local cfg = Login({ bloodlustConfig = {
    soundSource = "sharedmedia", sharedMediaSound = "Raid Horn", soundPath = sharedPath,
    voiceEnabled = true, imageEnabled = true, imageX = 47, voiceConditionTime = 3,
} })
Equal(cfg.soundSource, "sharedmedia", "saved SharedMedia choice beats the custom default")
Equal(cfg.imageEnabled, true, "saved Bloodlust visual settings beat defaults")
Equal(cfg.imageX, 47, "saved visual offset survives initialization")
Equal(cfg.voiceConditionTime, 3, "saved timing survives initialization")
assert(bloodlust:Rebuild(QFXSkillAlertsDB))
assert(bloodlust:PlayNotification(nil, notifier), "Bloodlust plays before opening settings or registering media")
Equal(played, sharedPath, "saved shared path is used while media registration is unavailable")
NS.MediaCatalog.FetchSharedMediaSoundPath = function() return "Interface\\AddOns\\SharedMedia\\UpdatedHorn.ogg" end
assert(bloodlust:PlayNotification(nil, notifier))
Equal(played, "Interface\\AddOns\\SharedMedia\\UpdatedHorn.ogg", "runtime uses media registered after login")
NS.MediaCatalog.FetchSharedMediaSoundPath = function() return "" end

-- The real editor must display and re-save the selected source, not convert it
-- when the SharedMedia registry is temporarily empty.
NS.API = { GetModes = function() return "tts", "sound" end }
dofile("QFXSkillAlerts_Config/Core/AceOptions.lua")
dofile("QFXSkillAlerts_Config/Core/AceOptionsCompat.lua")
dofile("QFXSkillAlerts_Config/Core/OptionsController.lua")
local options = NS.AceOptions
options:LoadBloodlustConfig()
Equal(options:GetState().soundSource, "sharedmedia", "editor keeps the source before media registration")
assert(options:SaveBloodlustConfig())
Equal(QFXSkillAlertsDB.bloodlustConfig.soundSource, "sharedmedia", "editor save persists the selected source")

aceDB.frame.OnEvent(aceDB.frame, "PLAYER_LOGOUT")
local ok, saved = serializer:Deserialize(serializer:Serialize(QFXSkillAlertsDB))
assert(ok)
cfg = Login(saved)
Equal(cfg.soundSource, "sharedmedia", "SharedMedia choice survives logout and next login")
Equal(cfg.sharedMediaSound, "Raid Horn", "SharedMedia name survives next login")
options:LoadBloodlustConfig()
Equal(options:GetState().soundSource, "sharedmedia", "editor still shows SharedMedia after next login")
assert(bloodlust:Rebuild(QFXSkillAlertsDB))
assert(bloodlust:PlayNotification(nil, notifier))
Equal(played, sharedPath, "next login keeps the fallback voice file")

-- Older broken logins stripped the custom default on logout, leaving the
-- SharedMedia name/path. Restore from those saved fields without an LSM lookup.
cfg = Login({ bloodlustConfig = {
    notifyMode = "sound", sharedMediaSound = "Raid Horn", soundPath = sharedPath, customSoundPath = "",
} })
Equal(cfg.soundSource, "sharedmedia", "missing source is recovered from the saved media name")

cfg = Login({ bloodlustConfig = {
    soundSource = "custom", sharedMediaSound = "Stale name", soundPath = "custom.ogg", customSoundPath = "",
} })
Equal(cfg.soundSource, "custom", "an explicit custom selection stays custom")
assert(bloodlust:Rebuild(QFXSkillAlertsDB))
assert(bloodlust:PlayNotification(nil, notifier), "blank custom slot must fall back to the saved soundPath")
Equal(played, "custom.ogg", "empty strings do not mask the custom fallback")

cfg = Login({
    profiles = { Default = { bloodlustConfig = { soundSource = "builtin", soundPath = "profile.ogg" } } },
    bloodlustConfig = { soundSource = "sharedmedia", sharedMediaSound = "Legacy name", soundPath = sharedPath },
})
Equal(cfg.soundSource, "builtin", "explicit active profile takes precedence over old flat data")
Equal(cfg.soundPath, "profile.ogg", "explicit profile path is retained")

LibStub = nil
database.initialized, database.db = nil, nil
dofile("QFXSkillAlerts/Core/Database.lua")
QFXSkillAlertsDB = { bloodlustConfig = { sharedMediaName = "Legacy alias", soundPath = sharedPath } }
database:Initialize()
Equal(QFXSkillAlertsDB.bloodlustConfig.soundSource, "sharedmedia", "non-AceDB initialization also recovers old media names")
print("Bloodlust login, source recovery and playback regression tests passed")

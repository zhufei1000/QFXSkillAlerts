local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local rebuildCalls, refreshCalls = 0, 0
QFXSkillAlertsNS = {
    API = {
        GetModes = function() return "tts", "sound" end,
        RebuildBloodlustConfig = function() rebuildCalls = rebuildCalls + 1 end,
        RefreshPanel = function() refreshCalls = refreshCalls + 1 end,
    },
}

-- Use the real selection, controller and sound-source implementations.
dofile("QFXSkillAlerts/Core/MediaCatalog.lua")
dofile("QFXSkillAlerts_Config/Core/AceOptions.lua")
dofile("QFXSkillAlerts_Config/Core/AceOptionsCompat.lua")
dofile("QFXSkillAlerts_Config/Core/OptionsController.lua")
dofile("QFXSkillAlerts_Config/Core/EntryStore.lua")

local options = QFXSkillAlertsNS.AceOptions
local state = options:GetState()

QFXSkillAlertsDB = nil
options:LoadBloodlustConfig()
Equal(type(QFXSkillAlertsDB.bloodlustConfig), "table", "opening a new configuration must initialize the DB")
Equal(state.entryType, "bloodlust", "new configuration must load the Bloodlust editor")
Equal(state.voiceEnabled, true, "new configuration must default to voice enabled")

local original = {
    voiceEnabled = true,
    notifyMode = "sound",
    soundSource = "custom",
    customSoundPaths = { "Interface\\Sounds\\Lust.ogg", "Interface\\Sounds\\Heroism.ogg" },
    imageEnabled = true,
    imageStrata = "FULLSCREEN_DIALOG",
    imageEndEvents = { PLAYER_DEAD = true },
    textEnabled = true,
    textAlert = "Bloodlust!",
    textEndEvents = { PLAYER_REGEN_ENABLED = true },
}
QFXSkillAlertsDB.bloodlustConfig = original
state.selectedKey = "bloodlust"
state.selectedCollectionKey = "group:1:1:test"
options:LoadSelectedEntry()
Equal(state.selectedCollectionKey, nil, "editing Bloodlust must clear collection selection")
Equal(state.customSoundPaths[2], original.customSoundPaths[2], "editing must preserve additional voice paths")
Equal(state.textAlert, "Bloodlust!", "editing must load existing text")
Equal(state.imageEndEvents.PLAYER_DEAD, true, "editing must preserve image end events")

local editedPath = "Interface\\Sounds\\EditedLust.ogg"
state.customSoundPaths[1] = editedPath
state.customSoundPath = editedPath
state.textAlert = "Edited Bloodlust!"
Equal(options:SaveBloodlustConfig(), true, "saving an edited Bloodlust configuration must succeed")
Equal(QFXSkillAlertsDB.bloodlustConfig, original, "saving must retain the existing configuration table")
Equal(original.soundPath, editedPath, "saving must persist the edited voice path")
Equal(original.customSoundPaths[2], "Interface\\Sounds\\Heroism.ogg", "saving must retain other voice paths")
Equal(state.customSoundPaths[1], editedPath, "saving must reload the edited path into the editor")
Equal(original.textAlert, "Edited Bloodlust!", "saving must persist text edits")
Equal(original.textEndEvents.PLAYER_REGEN_ENABLED, true, "saving must retain text end events")
Equal(rebuildCalls, 1, "successful save must rebuild Bloodlust runtime configuration")
Equal(refreshCalls, 1, "successful save must refresh the panel")

-- Saving also initializes a missing config, without requiring a prior load.
QFXSkillAlertsDB.bloodlustConfig = nil
state.soundSource = "tts"
state.notifyMode = "tts"
state.ttsText = "Bloodlust active"
Equal(options:SaveBloodlustConfig(), true, "saving must initialize a missing configuration")
Equal(QFXSkillAlertsDB.bloodlustConfig.ttsText, "Bloodlust active", "saving must persist TTS text")
Equal(state.soundSource, "tts", "saving must reload the TTS source")

print("bloodlust editor regression tests passed")

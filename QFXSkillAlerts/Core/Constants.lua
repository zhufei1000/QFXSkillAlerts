local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Constants = NS.Constants or {}
local C = NS.Constants

C.ENTRY_MIN = 1
C.ALL_CLASSES_ID = 0
C.ALL_SPECS_ID = 0
C.ALL_RACES_ID = 0

C.OBJECT_TYPE_SPELL = "spell"
C.OBJECT_TYPE_ITEM = "item"

C.ENTRY_TYPE_COOLDOWN = "cooldown"
C.ENTRY_TYPE_CAST = "cast"
C.ENTRY_TYPE_EVENT = "event"

C.ITEM_LOAD_NONE = "none"
C.ITEM_LOAD_EQUIPPED = "equipped"
C.ITEM_LOAD_BAGS = "bags"

C.MODE_TTS = "tts"
C.MODE_SOUND = "sound"

C.DEFAULT_COLLECTION_ICON = "Interface\\Icons\\INV_Misc_Note_01"

C.SOUND_ROOT = "Interface\\AddOns\\QFXSkillAlerts\\Media\\Sounds\\"
C.DEFAULT_BUILTIN_SOUND_FILE = "AirHorn.ogg"

C.UPDATE_INTERVAL_COMBAT = 0.10
C.UPDATE_INTERVAL_IDLE = 0.16

-- Display layer (frame strata) choices for image / text visual alerts.
-- FULLSCREEN_DIALOG keeps the historical always-on-top behavior and stays the
-- default for existing and new entries.
C.VISUAL_STRATA_OPTIONS = {
    "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}
C.VISUAL_STRATA_DEFAULT = "FULLSCREEN_DIALOG"

-- End-display events: when one of the selected events fires, the image or
-- text part of a running visual alert is hidden before its duration ends.
-- `unit = true` marks events whose first payload argument must be the player
-- unit so other units cannot end the display.
C.VISUAL_END_EVENTS = {
    { event = "PLAYER_DEAD" },
    { event = "PLAYER_ALIVE" },
    { event = "PLAYER_UNGHOST" },
    { event = "PLAYER_REGEN_DISABLED" },
    { event = "PLAYER_REGEN_ENABLED" },
    { event = "PLAYER_TARGET_CHANGED" },
    { event = "PLAYER_FOCUS_CHANGED" },
    { event = "PLAYER_STARTED_MOVING" },
    { event = "PLAYER_STOPPED_MOVING" },
    { event = "PLAYER_ENTERING_WORLD" },
    { event = "ZONE_CHANGED_NEW_AREA" },
    { event = "PLAYER_SPECIALIZATION_CHANGED", unit = true },
    { event = "PLAYER_MOUNT_DISPLAY_CHANGED" },
    { event = "ENCOUNTER_START" },
    { event = "ENCOUNTER_END" },
    { event = "PLAYER_LEVEL_UP" },
}

C.EXHAUSTION_IDS = { 57723, 57724, 80354, 95809, 160455, 207400, 264689, 390435 }
C.EXHAUSTION_DURATION = 600
C.FRESH_WINDOW = 5

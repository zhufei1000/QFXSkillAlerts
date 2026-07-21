local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

-- Read-only preset data shipped with the addon. Records use the same
-- classID/specID/recordKey hierarchy as the user preset store. Keep this file
-- data-only; runtime merge and synchronization live in the Core modules.
NS.CDMVoiceBuiltInPresets = NS.CDMVoiceBuiltInPresets or {}

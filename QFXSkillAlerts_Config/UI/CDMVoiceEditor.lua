local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.CDMVoiceEditor = NS.UI.CDMVoiceEditor or {}

local Editor = NS.UI.CDMVoiceEditor
local Controller = NS.Core.CDMVoiceEditorController

function Editor:Open()
    return Controller:Open()
end

function Editor:OpenForEdit(key)
    return Controller:OpenForEdit(key)
end

function Editor:Refresh(reason)
    return Controller:Refresh(reason)
end

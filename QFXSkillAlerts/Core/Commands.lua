local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Commands = NS.Core.Commands or {}

local Commands = NS.Core.Commands
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local function PrintMessage(text)
    print("[QFX-SA] " .. tostring(text or ""))
end

local function OpenMainFrame()
    if type(NS.LoadConfigAddon) == "function" then
        NS.LoadConfigAddon()
    end
    if not (NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function") then
        PrintMessage("Main frame is not ready yet.")
        return false
    end

    local ok, result = xpcall(function()
        return NS.UI.MainFrame:Open()
    end, function(err)
        return tostring(err or "unknown error")
    end)

    if not ok then
        PrintMessage("Open failed: " .. tostring(result or "unknown error"))
        return false
    end

    if result then
        return true
    end

    PrintMessage("Main frame did not open.")
    return false
end

function Commands:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    SLASH_QFXSKILLALERTS1 = "/qfxskillalerts"
    SLASH_QFXSKILLALERTS2 = "/qfxsa"
    SlashCmdList.QFXSKILLALERTS = function(msg)
        msg = tostring(msg or ""):match("^%s*(.-)%s*$")
        local cmd, arg = msg:match("^(%S+)%s*(.-)$")
        cmd = cmd and string.lower(cmd) or ""

        if cmd == "test" then
            local api = NS.API
            if not api then
                PrintMessage("API is not ready yet.")
                return
            end

            local index = tonumber(arg) or 0
            local classID, specID = api.GetCurrentClassSpec()
            local entry = api.GetEntry(api.GetStoredEntryMap(classID, specID), index)
            if not entry then
                PrintMessage("Entry not found.")
                return
            end
            api.PlayReadyNotification(entry)
            return
        end

        OpenMainFrame()
    end
end

Commands:Initialize()

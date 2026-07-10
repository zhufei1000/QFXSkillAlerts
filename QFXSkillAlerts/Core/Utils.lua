local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Utils = NS.Utils or {}
local Utils = NS.Utils

function Utils.TrimText(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Utils.CanonicalPath(value)
    local path = Utils.TrimText(value)
    if path == "" then
        return ""
    end
    return (path:gsub("/", "\\"))
end

function Utils.StripAudioExtension(fileName)
    local value = tostring(fileName or "")
    return (value:gsub("%.[Oo][Gg][Gg]$", ""):gsub("%.[Mm][Pp]3$", ""))
end

function Utils.GetFileNameFromPath(value)
    local path = tostring(value or ""):gsub("/", "\\")
    return path:match("([^\\]+)$") or path
end

function Utils.NormalizeIconID(value)
    local iconID = tonumber(Utils.TrimText(value))
    if iconID and iconID > 0 then
        return math.floor(iconID)
    end
    return nil
end

function Utils.ClampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if not number then
        number = fallback or 0
    end
    if minValue and number < minValue then
        number = minValue
    end
    if maxValue and number > maxValue then
        number = maxValue
    end
    return number
end

function Utils.SyncLinkedVisualDurations(target)
    if type(target) ~= "table" then
        return false
    end

    local imageEnabled = target.imageEnabled == true
    local textEnabled = target.textEnabled == true
    target.imageDuration = Utils.ClampNumber(target.imageDuration, 0.1, nil, 2)
    target.textDuration = Utils.ClampNumber(target.textDuration, 0.1, nil, 2)

    if imageEnabled and textEnabled then
        local linkedEnabled = target.imageDurationEnabled == true or target.textDurationEnabled == true
        target.imageDurationEnabled = linkedEnabled
        target.textDurationEnabled = linkedEnabled
        return true
    end

    target.imageDurationEnabled = target.imageDurationEnabled == true
    target.textDurationEnabled = target.textDurationEnabled == true
    return false
end

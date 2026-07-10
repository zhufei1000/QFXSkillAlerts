local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.PublicAPI = NS.Core.PublicAPI or {}

local PublicAPI = NS.Core.PublicAPI

function PublicAPI:Get()
    NS.API = NS.API or {}
    return NS.API
end

function PublicAPI:Install(exports)
    local api = self:Get()
    if type(exports) ~= "table" then
        return api
    end

    for name, fn in pairs(exports) do
        if type(name) == "string" and fn ~= nil then
            api[name] = fn
        end
    end

    return api
end

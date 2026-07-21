local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

local Store = NS.EntryStore
local Groups = NS.Core and NS.Core.VisualGroups
if not Store or not Groups then return end

local function State(owner)
    owner = owner or NS.AceOptions
    return owner and type(owner.GetState) == "function" and owner:GetState() or {}
end

local function RefreshRuntime()
    local api = NS.API
    if not api then return end
    if type(api.RebuildRuntimeConfig) == "function" then api.RebuildRuntimeConfig() end
    if type(api.RebuildCastSuccessConfig) == "function" then api.RebuildCastSuccessConfig() end
end

if type(Store.LoadSelectedEntry) == "function" and not Store.qfxsaVisualUIDLoad then
    Store.qfxsaVisualUIDLoad = true
    local original = Store.LoadSelectedEntry
    Store.LoadSelectedEntry = function(self, owner, ...)
        local result = original(self, owner, ...)
        local state = State(owner)
        local entry = Groups:GetSavedEntry(state.selectedKey)
        if entry then
            state.visualUID = Groups:EnsureVisualUID(entry, state._qfxPendingVisualUID)
        else
            state.visualUID = nil
        end
        return result
    end
end

if type(Store.SaveEntry) == "function" and not Store.qfxsaVisualUIDSave then
    Store.qfxsaVisualUIDSave = true
    local original = Store.SaveEntry
    Store.SaveEntry = function(self, owner, ...)
        local state = State(owner)
        local pending = tostring(state.visualUID or "")
        if pending == "" then pending = Groups:CreateVisualUID() end
        state._qfxPendingVisualUID = pending
        local result = original(self, owner, ...)
        if result == true then
            local entry = Groups:GetSavedEntry(state.selectedKey)
            state.visualUID = Groups:EnsureVisualUID(entry, pending)
            RefreshRuntime()
        end
        state._qfxPendingVisualUID = nil
        return result
    end
end

if type(Store.DeleteSelectedEntry) == "function" and not Store.qfxsaVisualUIDDelete then
    Store.qfxsaVisualUIDDelete = true
    local original = Store.DeleteSelectedEntry
    Store.DeleteSelectedEntry = function(self, owner, ...)
        local state = State(owner)
        local uid = tostring(state.visualUID or Groups:ResolveIdentity(state.selectedKey) or "")
        local result = original(self, owner, ...)
        if uid ~= "" then Groups:RemoveMember(uid, false) end
        state.visualUID = nil
        return result
    end
end

local originalPreviewGetter = NS.GetLoadedVisualPreviewConfigs
if type(originalPreviewGetter) == "function" and not NS.qfxsaVisualUIDPreviewWrapped then
    NS.qfxsaVisualUIDPreviewWrapped = true
    NS.GetLoadedVisualPreviewConfigs = function(...)
        local configs = originalPreviewGetter(...)
        if type(configs) == "table" then
            for _, cfg in ipairs(configs) do
                if type(cfg) == "table" then
                    cfg.visualUID = Groups:ResolveIdentity(cfg)
                end
            end
        end
        return configs
    end
end

if Groups:MigrateSavedEntries() > 0 then
    RefreshRuntime()
end

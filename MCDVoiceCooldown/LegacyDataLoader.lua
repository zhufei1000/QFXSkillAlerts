local CURRENT_DB_NAME = "QFXSkillAlertsDB"
local LEGACY_DB_NAME = "MCDVoiceCooldownDB"

local NS = rawget(_G, "QFXSkillAlertsNS")
local migration = NS and NS.Core and NS.Core.LegacyDatabaseMigration
local currentDB = rawget(_G, CURRENT_DB_NAME)
local legacyDB = rawget(_G, LEGACY_DB_NAME)

local function ClearLegacyData()
    if type(legacyDB) == "table" then
        for key in pairs(legacyDB) do
            legacyDB[key] = nil
        end
    end
    _G[LEGACY_DB_NAME] = nil
end

if migration and type(migration.Migrate) == "function" and type(currentDB) == "table" then
    local ok, result = migration:Migrate(legacyDB, currentDB)
    if ok then
        ClearLegacyData()
        if DEFAULT_CHAT_FRAME and result and not result.alreadyComplete then
            local added = tonumber(result.addedEntries) or 0
            local duplicates = tonumber(result.duplicates) or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff7f50[QFX-SA]|r 旧数据迁移完成：新增 %d 条，保留新版重复项 %d 条。", added, duplicates))
        end
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff7f50[QFX-SA]|r 旧数据迁移失败，旧数据已保留：" .. tostring(result and result.error or "unknown error"))
    end
elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff7f50[QFX-SA]|r 旧数据迁移组件未就绪，旧数据已保留。")
end

local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

local function NormalizeLanguageMode(value)
    value = tostring(value or "auto")
    if value == "zhCN" or value == "zhTW" or value == "enUS" then
        return value
    end
    return "auto"
end

local function DetectClientLocale()
    local rawLocale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    return (rawLocale == "zhCN" and "zhCN") or (rawLocale == "zhTW" and "zhTW") or "enUS"
end

local function GetSavedLanguageMode()
    local db = rawget(_G, "QFXSkillAlertsDB")
    if type(db) == "table" then
        return NormalizeLanguageMode(db.languageMode)
    end
    return "auto"
end

local function ResolveActiveLocale(mode)
    mode = NormalizeLanguageMode(mode)
    if mode == "auto" then
        return DetectClientLocale()
    end
    return mode
end

local activeLanguageMode = GetSavedLanguageMode()
local activeLocale = ResolveActiveLocale(activeLanguageMode)
NS.LOCALE = activeLocale

local enUS = {
    ADDON_DISPLAY_NAME = "QFX Skill Alerts",
    ADDON_SHORT_NAME = "QFX Alerts",
    
    AUTHOR_LINE = "Author: zhufei1000",
    OPTIONS_DESC = "Fixed-cooldown spell voice alerts: records successful casts via UNIT_SPELLCAST_SUCCEEDED, times cooldowns by the fixed CD you enter, and plays TTS or voice files when cooldowns finish, casts succeed, or Bloodlust is triggered.\n\nClick the button below to open the main settings window. You can also use /qfxsa or the minimap icon.",
    OPEN_MAIN_SETTINGS = "Open main settings",
    COMMANDS = "Commands: /qfxsa or /qfxskillalerts",

    BTN_ADD_VOICE = "Add Alert", BTN_ADD_COLLECTION = "Add Group", BTN_EDIT = "Edit", BTN_DELETE = "Delete", BTN_REFRESH = "Refresh", BTN_IMPORT = "Import", BTN_EXPORT_FULL = "Export All", BTN_SAVE = "Save", BTN_TEST = "Test", BTN_CLOSE = "Close", BTN_SELECT_ALL = "Select All",
    TITLE_NEW_CONFIG = "New Alert", TITLE_EDIT_CONFIG = "Edit Alert", TITLE_ADD_COLLECTION = "New Group", TITLE_RENAME_COLLECTION = "Rename Group", TITLE_IMPORT_EXPORT = "Import / Export", TITLE_EXPORT = "Export", TITLE_IMPORT_SETTINGS = "Import Settings", EXPORT_ENTRY = "Export Alert", EXPORT_COLLECTION = "Export Group", DELETE_ENTRY = "Delete Alert", EDIT_ENTRY = "Edit Alert", DELETE_COLLECTION_WITH_ITEMS = "Delete group and alerts", EXPAND_COLLECTION = "Expand Group", COLLAPSE_COLLECTION = "Collapse Group", RENAME_COLLECTION = "Rename Group", EXPORT_FULL_TITLE = "Export All",

    TAB_COOLDOWN = "Spell Alerts", TAB_CAST = "Cast Success", TAB_BLOODLUST = "Bloodlust", SECTION_CLASS_SPEC = "Class / Spec", LABEL_CLASS = "Class", LABEL_SPEC = "Spec", SECTION_SPELL_PARAMS = "Spell Settings", LABEL_SPELL_NAME = "Spell Name", LABEL_FIXED_CD_SEC = "Fixed CD (sec)", LABEL_CHECK_TALENT = "Talent changes CD", LABEL_TALENT_ID = "Talent ID", LABEL_TALENT_NAME = "Talent Name", LABEL_TALENT_CD_SEC = "New CD (sec)", LABEL_TALENT_LOAD_FILTER = "Load if learned", SECTION_NOTIFY = "Notification", LABEL_BUILTIN_SOUND = "Built-in Sound", LABEL_TTS_RATE = "TTS Rate", LABEL_SOUND_PATH_N = "Sound Path %d", 

    PLACEHOLDER_SELECT_CLASSES = "Select Classes", PLACEHOLDER_SELECT_SPECS = "Select Specs", PLACEHOLDER_SELECT_BUILTIN_SOUND = "Select built-in sound",
    COLLECTION_NAME = "Group Name", COLLECTION_ICON_ID = "Group Icon ID (optional)", COLLECTION_ICON_HINT = "Enter an in-game icon FileID, for example 134400. Leave it empty to use the default group icon.", COLLECTION_HINT = "After creation it appears in the Loaded area. Loaded and unloaded alerts can be dragged into groups; green/yellow/red dots show their status.", COLLECTION_UNNAMED = "Unnamed Group", COLLECTION_LABEL = "Group", COLLECTION_COUNT = "%d items", COLLECTION_EMPTY_COUNT = "(empty)", DRAG_INTO_COLLECTION = "Drag alerts into this group",
    HEADER_LOADED = "Loaded", HEADER_UNLOADED = "Unloaded", EMPTY_CONFIG = "No alerts", ENTRY_TYPE_COOLDOWN = "Spell Alert", ENTRY_TYPE_CAST = "Cast Success", ENTRY_TYPE_BLOODLUST = "Bloodlust", ENTRY_UNNAMED = "Unnamed", TALENT_ROW = "Talent:%s CD:%.2fs", TALENT_ROW_NO_CD = "Talent:%s", LOADED_TAG = " |cff00ff00Loaded|r", UNLOADED_TAG = " |cffff4040Unloaded|r",
    EXPORT_DESC = "Below is the compressed export string. Click \"Select All\" and press Ctrl+C to copy it. To import, paste this string into the same window.", IMPORT_DESC = "Paste a QFX Skill Alerts export string and click \"Import\". Supports single alerts, groups, and full imports. Full imports replace the current saved alerts, groups, sorting, Bloodlust, minimap, language, and UI skin settings.",
    MINIMAP_LEFT = "Left-click: open main settings", MINIMAP_RIGHT = "Right-click: open addon options", MINIMAP_DRAG = "Drag: move minimap icon", 
    MSG_MAIN_NOT_READY = "Main settings window is not ready yet.", MSG_MAIN_NOT_READY_LATER = "Main settings window is not ready yet. Please try again shortly.", MSG_NO_TTS = "No TTS voice is currently available.", MSG_TTS_FAILED = "TTS playback failed: %s", MSG_NO_CUSTOM_AUDIO = "This client cannot play custom audio.", MSG_SOUND_FAILED = "Voice file playback failed. Check path: %s", MSG_NO_CAST_SOUND_PATH = "Cast-success alert has no voice file path.", MSG_NO_BLOODLUST_SOUND_PATH = "Bloodlust alert has no voice path.", MSG_LOADED = "Loaded. Type /qfxsa or /qfxskillalerts to open settings.", MSG_SCOPE_COUNT = "%d spell alerts saved in the current scope.", MSG_CURRENT_EDIT_SCOPE = "Current class/spec: %s / %s", MSG_SELECTED_NOT_EXIST = "The selected alert no longer exists.", MSG_INVALID_CLASS_SPEC = "Class or spec is invalid.", MSG_INVALID_FIXED_CD = "Fixed CD is invalid.", MSG_NEED_TALENT_ID = "Talent check is enabled. Please enter a valid Talent ID.", MSG_NEED_TTS_TEXT = "TTS is enabled. Please enter announcement text.", MSG_NEED_SOUND_PATH = "Voice file is enabled. Please enter a sound path.", MSG_NEED_ALERT_ACTIONS = "Please select at least one alert action: Sound, Image, or Text.", MSG_SAVE_LIMIT = "Save limit reached.", MSG_CONFIG_SAVED = "Alert saved.", MSG_CHOOSE_CONFIG = "Please select an alert first.", MSG_CONFIG_DELETED = "Alert deleted.", MSG_IMPORT_FAILED = "Import failed: %s", MSG_IMPORT_UNKNOWN_TYPE = "Import failed: unknown import type.", MSG_IMPORT_DONE = "Import complete: %s, processed %d alerts.", MSG_IMPORT_EMPTY = "Import failed: no importable data.", MSG_DRAG_UNLOADED_TO_ROOT = "Unloaded alerts cannot be dragged to the loaded root area. Drag them into a loaded group instead.", MSG_DRAG_UNLOADED_TO_GROUP = "Unloaded alert added to this group. It will be shown with a red dot.",
    TTS_READY_DEFAULT = "Ready", TTS_CAST_SUCCESS_DEFAULT = "Cast success", FALLBACK_CLASS = "Class%s", FALLBACK_SPEC = "Spec%s",
}

local zhCN = setmetatable({
    ADDON_DISPLAY_NAME = "QFX 技能提醒", ADDON_SHORT_NAME = "QFX 技能提醒", AUTHOR_LINE = "作者：zhufei1000",
    OPTIONS_DESC = "固定CD技能语音提醒插件：通过 UNIT_SPELLCAST_SUCCEEDED 记录施法成功事件，按你填写的固定CD计时，并在冷却结束、施法成功或嗜血触发时播放TTS或语音文件。\n\n点击下方按钮可打开主设置界面；也可以使用 /qfxsa 或点击小地图图标打开。", OPEN_MAIN_SETTINGS = "打开主设置界面", COMMANDS = "命令：/qfxsa 或 /qfxskillalerts",
    BTN_ADD_VOICE = "新增", BTN_ADD_COLLECTION = "新增合集", BTN_EDIT = "编辑", BTN_DELETE = "删除", BTN_REFRESH = "刷新", BTN_IMPORT = "导入", BTN_EXPORT_FULL = "全量导出", BTN_SAVE = "保存", BTN_TEST = "试听", BTN_CLOSE = "关闭", BTN_SELECT_ALL = "全选",
    TITLE_NEW_CONFIG = "新增配置", TITLE_EDIT_CONFIG = "编辑配置", TITLE_ADD_COLLECTION = "新增合集", TITLE_RENAME_COLLECTION = "重命名合集", TITLE_IMPORT_EXPORT = "导入 / 导出", TITLE_EXPORT = "导出", TITLE_IMPORT_SETTINGS = "导入设置", EXPORT_ENTRY = "导出单条信息", EXPORT_COLLECTION = "导出合集", DELETE_ENTRY = "删除配置", EDIT_ENTRY = "编辑配置", DELETE_COLLECTION_WITH_ITEMS = "删除合集和其中语音", EXPAND_COLLECTION = "展开合集", COLLAPSE_COLLECTION = "收拢合集", RENAME_COLLECTION = "重命名合集", EXPORT_FULL_TITLE = "全量导出",
    TAB_COOLDOWN = "技能提醒", TAB_CAST = "施法成功", TAB_BLOODLUST = "嗜血提示", SECTION_CLASS_SPEC = "职业 / 专精", LABEL_CLASS = "职业", LABEL_SPEC = "专精", SECTION_SPELL_PARAMS = "技能参数", LABEL_SPELL_NAME = "技能名称", LABEL_FIXED_CD_SEC = "固定CD（秒）", LABEL_CHECK_TALENT = "检查天赋", LABEL_TALENT_ID = "天赋ID", LABEL_TALENT_NAME = "天赋名称", LABEL_TALENT_CD_SEC = "CD变为（秒）", LABEL_TALENT_LOAD_FILTER = "载入（仅点出时）", SECTION_NOTIFY = "通知方式", LABEL_BUILTIN_SOUND = "内置语音", LABEL_TTS_RATE = "TTS 语速", LABEL_SOUND_PATH_N = "语音路径 %d", 
    PLACEHOLDER_SELECT_CLASSES = "请选择职业", PLACEHOLDER_SELECT_SPECS = "请选择专精", PLACEHOLDER_SELECT_BUILTIN_SOUND = "请选择内置语音",
    COLLECTION_NAME = "合集名称", COLLECTION_ICON_ID = "合集图标ID（可选）", COLLECTION_ICON_HINT = "输入游戏内图标 FileID，例如 134400。留空时使用默认合集图标。", COLLECTION_HINT = "创建后显示在已载入区域；已载入/未载入语音都可以拖入合集，合集内用绿/黄/红圆点区分状态。", COLLECTION_UNNAMED = "未命名合集", COLLECTION_LABEL = "合集", COLLECTION_COUNT = "%d 条", COLLECTION_EMPTY_COUNT = "（空）", DRAG_INTO_COLLECTION = "拖拽语音到这个合集里",
    HEADER_LOADED = "已载入", HEADER_UNLOADED = "未载入", EMPTY_CONFIG = "暂无配置", ENTRY_TYPE_COOLDOWN = "技能提醒", ENTRY_TYPE_CAST = "施法成功", ENTRY_TYPE_BLOODLUST = "嗜血提示", ENTRY_UNNAMED = "未命名", TALENT_ROW = "天赋:%s CD:%.2fs", TALENT_ROW_NO_CD = "天赋:%s", LOADED_TAG = " |cff00ff00已载入|r", UNLOADED_TAG = " |cffff4040未载入|r",
    EXPORT_DESC = "下面是压缩后的导出字符串。点击“全选”后用 Ctrl+C 复制；导入时把这段字符串粘贴到同一个窗口。", IMPORT_DESC = "粘贴 QFX 技能提醒导出字符串后点击“导入”。支持单条信息、合集和全量导入；全量导入会替换当前已保存提示、合集、排序、嗜血、小地图、语言和界面皮肤设置。",
    MINIMAP_LEFT = "左键：打开主设置界面", MINIMAP_RIGHT = "右键：打开系统选项页", MINIMAP_DRAG = "拖动：移动小地图图标", 
    MSG_MAIN_NOT_READY = "主设置界面尚未准备好。", MSG_MAIN_NOT_READY_LATER = "主界面尚未准备好，请稍后再试。", MSG_NO_TTS = "当前没有可用的TTS语音。", MSG_TTS_FAILED = "TTS播放失败: %s", MSG_NO_CUSTOM_AUDIO = "当前客户端无法播放自定义音频。", MSG_SOUND_FAILED = "语音文件播放失败，请检查路径: %s", MSG_NO_CAST_SOUND_PATH = "施法成功提示未填写语音文件路径。", MSG_NO_BLOODLUST_SOUND_PATH = "嗜血提示未填写语音路径。", MSG_LOADED = "已载入，输入 /qfxsa 或 /qfxskillalerts 打开配置。", MSG_SCOPE_COUNT = "当前保存作用域已保存 %d 条技能配置。", MSG_CURRENT_EDIT_SCOPE = "当前职业专精：%s / %s", MSG_SELECTED_NOT_EXIST = "选中的配置不存在。", MSG_INVALID_CLASS_SPEC = "职业或专精无效。", MSG_INVALID_FIXED_CD = "固定CD无效。", MSG_NEED_TALENT_ID = "已启用检查天赋，请填写有效的天赋ID。", MSG_NEED_TTS_TEXT = "已启用TTS，请填写播报文本。", MSG_NEED_SOUND_PATH = "已启用语音文件，请填写语音路径。", MSG_NEED_ALERT_ACTIONS = "请至少选择一种提示方式：声音、图片或文本。", MSG_SAVE_LIMIT = "已达到保存上限。", MSG_CONFIG_SAVED = "配置已保存。", MSG_CHOOSE_CONFIG = "请先选择一条配置。", MSG_CONFIG_DELETED = "配置已删除。", MSG_IMPORT_FAILED = "导入失败：%s", MSG_IMPORT_UNKNOWN_TYPE = "导入失败：未知导入类型。", MSG_IMPORT_DONE = "导入完成：%s，处理 %d 条语音配置。", MSG_IMPORT_EMPTY = "导入失败：没有可导入的数据。", MSG_DRAG_UNLOADED_TO_ROOT = "未载入条目不能单独拖到已载入区域，只能拖入已载入合集。", MSG_DRAG_UNLOADED_TO_GROUP = "已把未载入语音加入当前合集，状态会以红色圆点显示。",
    TTS_READY_DEFAULT = "好了", TTS_CAST_SUCCESS_DEFAULT = "施法成功", FALLBACK_CLASS = "职业%s", FALLBACK_SPEC = "专精%s",
}, { __index = enUS })

local zhTW = setmetatable({
    ADDON_DISPLAY_NAME = "QFX 技能提醒", ADDON_SHORT_NAME = "QFX 技能提醒", AUTHOR_LINE = "作者：zhufei1000",
    OPTIONS_DESC = "固定冷卻技能語音提醒插件：透過 UNIT_SPELLCAST_SUCCEEDED 記錄施法成功事件，依照你填寫的固定冷卻計時，並在冷卻結束、施法成功或嗜血觸發時播放 TTS 或語音檔。\n\n點擊下方按鈕可開啟主設定介面；也可以使用 /qfxsa 或點擊小地圖圖示開啟。", OPEN_MAIN_SETTINGS = "開啟主設定介面", COMMANDS = "指令：/qfxsa 或 /qfxskillalerts",
    BTN_ADD_VOICE = "新增", BTN_ADD_COLLECTION = "新增合集", BTN_EDIT = "編輯", BTN_DELETE = "刪除", BTN_REFRESH = "重新整理", BTN_IMPORT = "匯入", BTN_EXPORT_FULL = "全量匯出", BTN_SAVE = "儲存", BTN_TEST = "試聽", BTN_CLOSE = "關閉", BTN_SELECT_ALL = "全選",
    TITLE_NEW_CONFIG = "新增設定", TITLE_EDIT_CONFIG = "編輯設定", TITLE_ADD_COLLECTION = "新增合集", TITLE_RENAME_COLLECTION = "重命名合集", TITLE_IMPORT_EXPORT = "匯入 / 匯出", TITLE_EXPORT = "匯出", TITLE_IMPORT_SETTINGS = "匯入設定", EXPORT_ENTRY = "匯出單條資訊", EXPORT_COLLECTION = "匯出合集", DELETE_ENTRY = "刪除設定", EDIT_ENTRY = "編輯設定", DELETE_COLLECTION_WITH_ITEMS = "刪除合集和其中語音", EXPAND_COLLECTION = "展開合集", COLLAPSE_COLLECTION = "收合合集", EXPORT_FULL_TITLE = "全量匯出",
    TAB_COOLDOWN = "技能提醒", TAB_CAST = "施法成功", TAB_BLOODLUST = "嗜血提示", SECTION_CLASS_SPEC = "職業 / 專精", LABEL_CLASS = "職業", LABEL_SPEC = "專精", SECTION_SPELL_PARAMS = "技能參數", LABEL_SPELL_NAME = "技能名稱", LABEL_FIXED_CD_SEC = "固定CD（秒）", LABEL_CHECK_TALENT = "檢查天賦", LABEL_TALENT_ID = "天賦ID", LABEL_TALENT_NAME = "天賦名稱", LABEL_TALENT_CD_SEC = "CD變為（秒）", LABEL_TALENT_LOAD_FILTER = "載入（僅點出時）", SECTION_NOTIFY = "通知方式", LABEL_BUILTIN_SOUND = "內建語音", LABEL_TTS_RATE = "TTS 語速", LABEL_SOUND_PATH_N = "語音路徑 %d", 
    PLACEHOLDER_SELECT_CLASSES = "請選擇職業", PLACEHOLDER_SELECT_SPECS = "請選擇專精", PLACEHOLDER_SELECT_BUILTIN_SOUND = "請選擇內建語音",
    COLLECTION_NAME = "合集名稱", COLLECTION_ICON_ID = "合集圖示ID（可選）", COLLECTION_ICON_HINT = "輸入遊戲內圖示 FileID，例如 134400。留空時使用預設合集圖示。", COLLECTION_HINT = "建立後顯示在已載入區域；已載入/未載入語音都可以拖入合集，合集內用綠/黃/紅圓點區分狀態。", COLLECTION_UNNAMED = "未命名合集", COLLECTION_LABEL = "合集", COLLECTION_COUNT = "%d 條", COLLECTION_EMPTY_COUNT = "（空）", DRAG_INTO_COLLECTION = "拖曳語音到這個合集裡",
    HEADER_LOADED = "已載入", HEADER_UNLOADED = "未載入", EMPTY_CONFIG = "暫無設定", ENTRY_TYPE_COOLDOWN = "技能提醒", ENTRY_TYPE_CAST = "施法成功", ENTRY_TYPE_BLOODLUST = "嗜血提示", ENTRY_UNNAMED = "未命名", TALENT_ROW = "天賦:%s CD:%.2fs", TALENT_ROW_NO_CD = "天賦:%s", LOADED_TAG = " |cff00ff00已載入|r", UNLOADED_TAG = " |cffff4040未載入|r",
    MINIMAP_LEFT = "左鍵：開啟主設定介面", MINIMAP_RIGHT = "右鍵：開啟系統選項頁", MINIMAP_DRAG = "拖曳：移動小地圖圖示", 
    TTS_READY_DEFAULT = "好了", TTS_CAST_SUCCESS_DEFAULT = "施法成功", FALLBACK_CLASS = "職業%s", FALLBACK_SPEC = "專精%s",
}, { __index = zhCN })


-- Additional legacy/utility UI strings.
enUS.BTN_CREATE = "Create"; enUS.BTN_CANCEL = "Cancel"
enUS.CREATE_CHILD_COLLECTION = "Create Child Group"; enUS.CREATE_VOICE_IN_COLLECTION = "Create Alert in Group"
enUS.ADD_ENTRY_TO_COLLECTION = "Add to Existing Group"
enUS.NO_AVAILABLE_COLLECTION = "No other groups available"
enUS.CONTEXT_MENU_BACK = "< Back"
enUS.CONTEXT_MENU_PREVIOUS_PAGE = "< Page %d / %d"
enUS.CONTEXT_MENU_NEXT_PAGE = "Page %d / %d >"
enUS.MSG_ENTRY_ADDED_TO_COLLECTION = "Alert added to group: %s"
enUS.SELECT_COLLECTION_ALERT_TYPE_DESC = "Choose the alert type to create in this group."
enUS.MSG_BLOODLUST_SAVED = "Bloodlust voice settings saved."
enUS.MSG_INVALID_SCOPE = "Please select a valid class/spec first."
enUS.MSG_COLLECTION_NAME_EMPTY = "Group name cannot be empty."
enUS.MSG_COLLECTION_ADDED = "Group added: %s"
enUS.MSG_COLLECTION_DELETED = "Group deleted, and %d alerts inside it were also deleted."

enUS.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "Unloaded alerts can only be dragged into groups in the currently loaded area."
enUS.MSG_EXPORT_MISSING_LIBS = "Export failed: AceSerializer or LibDeflate is missing."
enUS.MSG_EXPORT_DEFLATE_FAILED = "Export failed: data compression failed."
enUS.ERR_IMPORT_EMPTY = "Import string is empty."
enUS.ERR_IMPORT_MISSING_LIBS = "AceSerializer or LibDeflate is missing."
enUS.ERR_IMPORT_BAD_PREFIX = "This is not a QFX Skill Alerts import string."
enUS.ERR_IMPORT_DECODE_FAILED = "Import string decode failed."
enUS.ERR_IMPORT_DEFLATE_FAILED = "Import string decompression failed."
enUS.ERR_IMPORT_DESERIALIZE_FAILED = "Import string deserialization failed."
enUS.ERR_IMPORT_VERSION_MISMATCH = "Import string version mismatch."
enUS.MSG_EXPORT_ENTRY_NOT_FOUND = "Export failed: saved alert not found."
enUS.MSG_EXPORT_COLLECTION_INVALID = "Export failed: invalid group."
enUS.MSG_EXPORT_COLLECTION_NOT_FOUND = "Export failed: group not found."
enUS.IMPORT_COLLECTION_NAME = "Imported Group"

enUS.MSG_ITEM_TRIGGER_PENDING_SAVED = "Item ID %s has been saved, but its use-trigger spell ID has not been resolved yet. It will be completed after combat ends or item data loads."
enUS.MSG_ITEM_TRIGGER_AUTO_FILLED = "Item use-trigger spell ID was completed automatically."
enUS.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "Item ID %s has not resolved to a use-trigger spell ID yet. It is queued until item data loads or combat ends."

zhCN.BTN_CREATE = "创建"; zhCN.BTN_CANCEL = "取消"
zhCN.CREATE_CHILD_COLLECTION = "创建子合集"; zhCN.CREATE_VOICE_IN_COLLECTION = "创建语音"
zhCN.ADD_ENTRY_TO_COLLECTION = "加入到现有合集"
zhCN.NO_AVAILABLE_COLLECTION = "没有其他可用合集"
zhCN.CONTEXT_MENU_BACK = "< 返回"
zhCN.CONTEXT_MENU_PREVIOUS_PAGE = "< 第 %d / %d 页"
zhCN.CONTEXT_MENU_NEXT_PAGE = "第 %d / %d 页 >"
zhCN.MSG_ENTRY_ADDED_TO_COLLECTION = "已加入合集：%s"
zhCN.SELECT_COLLECTION_ALERT_TYPE_DESC = "请选择要在此合集中创建的提醒类型。"
zhCN.MSG_BLOODLUST_SAVED = "嗜血语音配置已保存。"
zhCN.MSG_INVALID_SCOPE = "请先选择有效的职业/专精。"
zhCN.MSG_COLLECTION_NAME_EMPTY = "合集名称不能为空。"
zhCN.MSG_COLLECTION_ADDED = "已新增合集：%s"
zhCN.MSG_COLLECTION_DELETED = "合集已删除，并删除其中 %d 条语音配置。"

zhCN.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "未载入条目只能拖入当前已载入区域的合集。"
zhCN.MSG_EXPORT_MISSING_LIBS = "导出失败：缺少 AceSerializer 或 LibDeflate。"
zhCN.MSG_EXPORT_DEFLATE_FAILED = "导出失败：压缩数据失败。"
zhCN.ERR_IMPORT_EMPTY = "导入字符串为空。"
zhCN.ERR_IMPORT_MISSING_LIBS = "缺少 AceSerializer 或 LibDeflate。"
zhCN.ERR_IMPORT_BAD_PREFIX = "不是 QFX 技能提醒的导入字符串。"
zhCN.ERR_IMPORT_DECODE_FAILED = "导入字符串解码失败。"
zhCN.ERR_IMPORT_DEFLATE_FAILED = "导入字符串解压失败。"
zhCN.ERR_IMPORT_DESERIALIZE_FAILED = "导入字符串反序列化失败。"
zhCN.ERR_IMPORT_VERSION_MISMATCH = "导入字符串版本不匹配。"
zhCN.MSG_EXPORT_ENTRY_NOT_FOUND = "导出失败：找不到这条保存信息。"
zhCN.MSG_EXPORT_COLLECTION_INVALID = "导出失败：合集无效。"
zhCN.MSG_EXPORT_COLLECTION_NOT_FOUND = "导出失败：找不到合集。"
zhCN.IMPORT_COLLECTION_NAME = "导入合集"

zhCN.MSG_ITEM_TRIGGER_PENDING_SAVED = "物品ID %s 已保存，但暂未解析到触发法术ID；脱战或物品资料加载后会自动补全。"
zhCN.MSG_ITEM_TRIGGER_AUTO_FILLED = "已自动补全物品触发法术ID。"
zhCN.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "物品ID %s 暂时没有解析到触发法术ID，已等待物品资料加载或脱战后自动补全。"

zhTW.BTN_CREATE = "建立"; zhTW.BTN_CANCEL = "取消"
zhTW.CREATE_CHILD_COLLECTION = "建立子合集"; zhTW.CREATE_VOICE_IN_COLLECTION = "建立語音"
zhTW.ADD_ENTRY_TO_COLLECTION = "加入到現有合集"
zhTW.NO_AVAILABLE_COLLECTION = "沒有其他可用合集"
zhTW.CONTEXT_MENU_BACK = "< 返回"
zhTW.CONTEXT_MENU_PREVIOUS_PAGE = "< 第 %d / %d 頁"
zhTW.CONTEXT_MENU_NEXT_PAGE = "第 %d / %d 頁 >"
zhTW.MSG_ENTRY_ADDED_TO_COLLECTION = "已加入合集：%s"
zhTW.SELECT_COLLECTION_ALERT_TYPE_DESC = "請選擇要在此合集中建立的提醒類型。"
zhTW.MSG_BLOODLUST_SAVED = "嗜血語音設定已儲存。"
zhTW.MSG_INVALID_SCOPE = "請先選擇有效的職業/專精。"
zhTW.MSG_COLLECTION_NAME_EMPTY = "合集名稱不能為空。"
zhTW.MSG_COLLECTION_ADDED = "已新增合集：%s"
zhTW.MSG_COLLECTION_DELETED = "合集已刪除，並刪除其中 %d 條語音設定。"

zhTW.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "未載入條目只能拖入目前已載入區域的合集。"
zhTW.MSG_EXPORT_MISSING_LIBS = "匯出失敗：缺少 AceSerializer 或 LibDeflate。"
zhTW.MSG_EXPORT_DEFLATE_FAILED = "匯出失敗：壓縮資料失敗。"
zhTW.ERR_IMPORT_EMPTY = "匯入字串為空。"
zhTW.ERR_IMPORT_MISSING_LIBS = "缺少 AceSerializer 或 LibDeflate。"
zhTW.ERR_IMPORT_BAD_PREFIX = "不是 QFX 技能提醒的匯入字串。"
zhTW.ERR_IMPORT_DECODE_FAILED = "匯入字串解碼失敗。"
zhTW.ERR_IMPORT_DEFLATE_FAILED = "匯入字串解壓失敗。"
zhTW.ERR_IMPORT_DESERIALIZE_FAILED = "匯入字串反序列化失敗。"
zhTW.ERR_IMPORT_VERSION_MISMATCH = "匯入字串版本不相符。"
zhTW.MSG_EXPORT_ENTRY_NOT_FOUND = "匯出失敗：找不到這條儲存資訊。"
zhTW.MSG_EXPORT_COLLECTION_INVALID = "匯出失敗：合集無效。"
zhTW.MSG_EXPORT_COLLECTION_NOT_FOUND = "匯出失敗：找不到合集。"
zhTW.IMPORT_COLLECTION_NAME = "匯入合集"

zhTW.MSG_ITEM_TRIGGER_PENDING_SAVED = "物品ID %s 已儲存，但暫未解析到觸發法術ID；脫戰或物品資料載入後會自動補全。"
zhTW.MSG_ITEM_TRIGGER_AUTO_FILLED = "已自動補全物品觸發法術ID。"
zhTW.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "物品ID %s 暫時沒有解析到觸發法術ID，已等待物品資料載入或脫戰後自動補全。"



zhTW.EXPORT_DESC = "下面是壓縮後的匯出字串。點擊「全選」後用 Ctrl+C 複製；匯入時把這段字串貼到同一個視窗。"
zhTW.IMPORT_DESC = "貼上 QFX 技能提醒匯出字串後點擊「匯入」。支援單條資訊、合集和全量匯入；全量匯入會取代目前已儲存提示、合集、排序、嗜血、小地圖、語言和介面外觀設定。"
zhTW.MSG_MAIN_NOT_READY = "主設定介面尚未準備好。"
zhTW.MSG_MAIN_NOT_READY_LATER = "主介面尚未準備好，請稍後再試。"
zhTW.MSG_NO_TTS = "目前沒有可用的 TTS 語音。"
zhTW.MSG_TTS_FAILED = "TTS播放失敗: %s"
zhTW.MSG_NO_CUSTOM_AUDIO = "目前客戶端無法播放自訂音訊。"
zhTW.MSG_SOUND_FAILED = "語音檔播放失敗，請檢查路徑: %s"
zhTW.MSG_NO_CAST_SOUND_PATH = "施法成功提示未填寫語音檔路徑。"
zhTW.MSG_NO_BLOODLUST_SOUND_PATH = "嗜血提示未填寫語音路徑。"
zhTW.MSG_LOADED = "已載入，輸入 /qfxsa 或 /qfxskillalerts 開啟設定。"
zhTW.MSG_SCOPE_COUNT = "目前儲存作用域已儲存 %d 條技能設定。"
zhTW.MSG_CURRENT_EDIT_SCOPE = "目前職業專精：%s / %s"
zhTW.MSG_SELECTED_NOT_EXIST = "選中的設定不存在。"
zhTW.MSG_INVALID_CLASS_SPEC = "職業或專精無效。"
zhTW.MSG_INVALID_FIXED_CD = "固定CD無效。"
zhTW.MSG_NEED_TALENT_ID = "已啟用檢查天賦，請填寫有效的天賦ID。"

zhTW.MSG_NEED_TTS_TEXT = "已啟用TTS，請填寫播報文字。"
zhTW.MSG_NEED_SOUND_PATH = "已啟用語音檔，請填寫語音路徑。"
zhTW.MSG_NEED_ALERT_ACTIONS = "請至少選擇一種提示方式：聲音、圖片或文字。"
zhTW.MSG_SAVE_LIMIT = "已達到儲存上限。"
zhTW.MSG_CONFIG_SAVED = "設定已儲存。"
zhTW.MSG_CHOOSE_CONFIG = "請先選擇一條設定。"
zhTW.MSG_CONFIG_DELETED = "設定已刪除。"
zhTW.MSG_IMPORT_FAILED = "匯入失敗：%s"
zhTW.MSG_IMPORT_UNKNOWN_TYPE = "匯入失敗：未知匯入類型。"
zhTW.MSG_IMPORT_DONE = "匯入完成：%s，處理 %d 條語音設定。"
zhTW.MSG_IMPORT_EMPTY = "匯入失敗：沒有可匯入的資料。"

zhTW.MSG_DRAG_UNLOADED_TO_ROOT = "未載入條目不能單獨拖到已載入區域，只能拖入已載入合集。"
zhTW.MSG_DRAG_UNLOADED_TO_GROUP = "已把未載入語音加入目前合集，狀態會以紅色圓點顯示。"






enUS.SCOPE_ALL_RACES = "All Races"
enUS.SCOPE_ALL_CLASSES = "All Classes"
enUS.SCOPE_ALL_SPECS = "All Specs"
enUS.SCOPE_RACE_COUNT = "%d Races"
enUS.SCOPE_CLASS_COUNT = "%d Classes"
enUS.SCOPE_SPEC_COUNT = "%d Specs"


enUS.PLACEHOLDER_SELECT_RACES = "Select Races"
enUS.SAVED_SCOPE_RACES = "Race:%s"
enUS.COLLECTION_COUNT_MIXED = "%d items (%d loaded / %d unloaded)"






zhCN.SCOPE_ALL_RACES = "全种族"
zhCN.SCOPE_ALL_CLASSES = "全职业"
zhCN.SCOPE_ALL_SPECS = "全专精"
zhCN.SCOPE_RACE_COUNT = "%d 个种族"
zhCN.SCOPE_CLASS_COUNT = "%d 个职业"
zhCN.SCOPE_SPEC_COUNT = "%d 个专精"


zhCN.PLACEHOLDER_SELECT_RACES = "选择种族"
zhCN.SAVED_SCOPE_RACES = "种族:%s"
zhCN.COLLECTION_COUNT_MIXED = "%d 条（已载入 %d / 未载入 %d）"






zhTW.SCOPE_ALL_RACES = "全種族"
zhTW.SCOPE_ALL_CLASSES = "全職業"
zhTW.SCOPE_ALL_SPECS = "全專精"
zhTW.SCOPE_RACE_COUNT = "%d 個種族"
zhTW.SCOPE_CLASS_COUNT = "%d 個職業"
zhTW.SCOPE_SPEC_COUNT = "%d 個專精"


zhTW.PLACEHOLDER_SELECT_RACES = "選擇種族"
zhTW.SAVED_SCOPE_RACES = "種族:%s"
zhTW.COLLECTION_COUNT_MIXED = "%d 條（已載入 %d / 未載入 %d）"





enUS.ALL_SPECS = "All Specs"
zhCN.ALL_SPECS = "全专精"
zhTW.ALL_SPECS = "全專精"


-- All class / all spec and spell-or-item unified labels.
enUS.ALL_CLASSES = "All Classes"
zhCN.ALL_CLASSES = "全职业"
zhTW.ALL_CLASSES = "全職業"






enUS.LABEL_SPELL_NAME = "Spell / Item Name"
zhCN.LABEL_SPELL_NAME = "技能/物品名称"
zhTW.LABEL_SPELL_NAME = "技能/物品名稱"

enUS.MSG_INVALID_SPELL_ID = "Spell / item ID is invalid."
zhCN.MSG_INVALID_SPELL_ID = "技能/物品ID无效。"
zhTW.MSG_INVALID_SPELL_ID = "技能/物品ID無效。"

enUS.MSG_DUP_SPELL = "The current scope already has the same spell/item ID and alert type."
zhCN.MSG_DUP_SPELL = "当前范围下已经存在相同的技能/物品ID和提醒类型。"
zhTW.MSG_DUP_SPELL = "目前範圍下已經存在相同的技能/物品ID和提醒類型。"

enUS.MSG_NO_SOUND_PATH = "This spell/item has no voice file path."
zhCN.MSG_NO_SOUND_PATH = "这条技能/物品未填写语音文件路径。"
zhTW.MSG_NO_SOUND_PATH = "這條技能/物品未填寫語音檔路徑。"

enUS.ENTRY_OBJECT_SPELL_ID = "Spell / Item ID"
zhCN.ENTRY_OBJECT_SPELL_ID = "技能/物品ID"
zhTW.ENTRY_OBJECT_SPELL_ID = "技能/物品ID"

enUS.ENTRY_OBJECT_ITEM_ID = "Spell / Item ID"
zhCN.ENTRY_OBJECT_ITEM_ID = "技能/物品ID"
zhTW.ENTRY_OBJECT_ITEM_ID = "技能/物品ID"



enUS.SECTION_SPELL_PARAMS = "Spell / Item Settings"
zhCN.SECTION_SPELL_PARAMS = "技能/物品参数"
zhTW.SECTION_SPELL_PARAMS = "技能/物品參數"





enUS.LABEL_OBJECT_TYPE = "Type"
zhCN.LABEL_OBJECT_TYPE = "类型"
zhTW.LABEL_OBJECT_TYPE = "類型"

enUS.OBJECT_TYPE_SPELL = "Spell"
zhCN.OBJECT_TYPE_SPELL = "技能"
zhTW.OBJECT_TYPE_SPELL = "技能"

enUS.OBJECT_TYPE_ITEM = "Item"
zhCN.OBJECT_TYPE_ITEM = "物品"
zhTW.OBJECT_TYPE_ITEM = "物品"

enUS.LABEL_SCOPE_RACE = "Race"
zhCN.LABEL_SCOPE_RACE = "种族"
zhTW.LABEL_SCOPE_RACE = "種族"

enUS.LABEL_ITEM_LOAD_EQUIPPED = "Check Equipped"
zhCN.LABEL_ITEM_LOAD_EQUIPPED = "检测装备"
zhTW.LABEL_ITEM_LOAD_EQUIPPED = "檢測裝備"

enUS.LABEL_ITEM_LOAD_BAGS = "Check Bags"
zhCN.LABEL_ITEM_LOAD_BAGS = "检测背包"
zhTW.LABEL_ITEM_LOAD_BAGS = "檢測背包"

enUS.LABEL_ITEM_LOAD_SAME_NAME = "Same Name"
zhCN.LABEL_ITEM_LOAD_SAME_NAME = "同名物品"
zhTW.LABEL_ITEM_LOAD_SAME_NAME = "同名物品"

enUS.SAVED_ITEM_LOAD_EQUIPPED = "Load: Equipped"
zhCN.SAVED_ITEM_LOAD_EQUIPPED = "载入：已装备"
zhTW.SAVED_ITEM_LOAD_EQUIPPED = "載入：已裝備"

enUS.SAVED_ITEM_LOAD_BAGS = "Load: In bags"
zhCN.SAVED_ITEM_LOAD_BAGS = "载入：背包内"
zhTW.SAVED_ITEM_LOAD_BAGS = "載入：背包內"

enUS.SAVED_ITEM_LOAD_SAME_NAME = "Same name"
zhCN.SAVED_ITEM_LOAD_SAME_NAME = "同名"
zhTW.SAVED_ITEM_LOAD_SAME_NAME = "同名"

enUS.SAVED_CD_MODE_FIXED = "CD Type: Fixed"
zhCN.SAVED_CD_MODE_FIXED = "CD类型：固定"
zhTW.SAVED_CD_MODE_FIXED = "CD類型：固定"

enUS.SAVED_CD_MODE_READY = "CD Type: Ready"
zhCN.SAVED_CD_MODE_READY = "CD类型：就绪"
zhTW.SAVED_CD_MODE_READY = "CD類型：就緒"

enUS.SAVED_CD_MODE_COOLDOWN = "CD Type: On Cooldown"
zhCN.SAVED_CD_MODE_COOLDOWN = "CD类型：冷却中"
zhTW.SAVED_CD_MODE_COOLDOWN = "CD類型：冷卻中"
enUS.LABEL_ITEM_ID = "Item ID"
zhCN.LABEL_ITEM_ID = "物品ID"
zhTW.LABEL_ITEM_ID = "物品ID"
enUS.LABEL_OBJECT_SPELL_ID = "Spell ID"
zhCN.LABEL_OBJECT_SPELL_ID = "技能ID"
zhTW.LABEL_OBJECT_SPELL_ID = "技能ID"


-- Collection rename labels.
enUS.TITLE_RENAME_COLLECTION = enUS.TITLE_RENAME_COLLECTION or "Rename Group"
zhCN.TITLE_RENAME_COLLECTION = zhCN.TITLE_RENAME_COLLECTION or "重命名合集"
zhTW.TITLE_RENAME_COLLECTION = zhTW.TITLE_RENAME_COLLECTION or "重新命名合集"
enUS.RENAME_COLLECTION = enUS.RENAME_COLLECTION or "Rename Group"
zhCN.RENAME_COLLECTION = zhCN.RENAME_COLLECTION or "重命名合集"
zhTW.RENAME_COLLECTION = zhTW.RENAME_COLLECTION or "重新命名合集"
enUS.MSG_COLLECTION_RENAMED = enUS.MSG_COLLECTION_RENAMED or "Group renamed: %s"
zhCN.MSG_COLLECTION_RENAMED = zhCN.MSG_COLLECTION_RENAMED or "合集已重命名：%s"
zhTW.MSG_COLLECTION_RENAMED = zhTW.MSG_COLLECTION_RENAMED or "合集已重新命名：%s"

-- Saved list voice detail labels.
enUS.SAVED_VOICE_BUILTIN = "Voice  Built-in: %s"
zhCN.SAVED_VOICE_BUILTIN = "语音  内置语音：%s"
zhTW.SAVED_VOICE_BUILTIN = "語音  內建語音：%s"

enUS.SAVED_VOICE_CUSTOM = "Voice  Custom: %s"
zhCN.SAVED_VOICE_CUSTOM = "语音  自定义语音：%s"
zhTW.SAVED_VOICE_CUSTOM = "語音  自訂語音：%s"

enUS.SAVED_VOICE_TTS = "Voice  TTS text: %s"
zhCN.SAVED_VOICE_TTS = "语音  TTS文本：%s"
zhTW.SAVED_VOICE_TTS = "語音  TTS文字：%s"

enUS.SAVED_VOICE_SHAREDMEDIA = "Voice  SharedMedia: %s"
zhCN.SAVED_VOICE_SHAREDMEDIA = "语音  共享媒体：%s"
zhTW.SAVED_VOICE_SHAREDMEDIA = "語音  共享媒體：%s"

enUS.LABEL_SHAREDMEDIA_SOUND = "SharedMedia Sound"
zhCN.LABEL_SHAREDMEDIA_SOUND = "共享媒体语音"
zhTW.LABEL_SHAREDMEDIA_SOUND = "共享媒體語音"
enUS.LABEL_SOUND_SOURCE = "Voice Source"
zhCN.LABEL_SOUND_SOURCE = "语音来源"
zhTW.LABEL_SOUND_SOURCE = "語音來源"
enUS.SOURCE_BUILTIN = "Built-in Sound"
zhCN.SOURCE_BUILTIN = "内置语音"
zhTW.SOURCE_BUILTIN = "內建語音"
enUS.SOURCE_SHAREDMEDIA = "LibSharedMedia"
zhCN.SOURCE_SHAREDMEDIA = "共享媒体"
zhTW.SOURCE_SHAREDMEDIA = "共享媒體"
enUS.SOURCE_CUSTOM = "Custom Path"
zhCN.SOURCE_CUSTOM = "自定义路径"
zhTW.SOURCE_CUSTOM = "自訂路徑"
enUS.SOURCE_TTS = "TTS Text"
zhCN.SOURCE_TTS = "TTS 文本"
zhTW.SOURCE_TTS = "TTS 文字"

enUS.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "Select SharedMedia sound"
zhCN.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "选择共享媒体语音"
zhTW.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "選擇共享媒體語音"

-- Manual language switching and cast-success delay labels.
enUS.LABEL_LANGUAGE = "Language"
zhCN.LABEL_LANGUAGE = "语言"
zhTW.LABEL_LANGUAGE = "語言"

enUS.LANGUAGE_AUTO = "Follow Client"
zhCN.LANGUAGE_AUTO = "跟随客户端"
zhTW.LANGUAGE_AUTO = "跟隨客戶端"

enUS.LANGUAGE_ENUS = "English"
zhCN.LANGUAGE_ENUS = "English"
zhTW.LANGUAGE_ENUS = "English"

enUS.LANGUAGE_ZHCN = "简体中文"
zhCN.LANGUAGE_ZHCN = "简体中文"
zhTW.LANGUAGE_ZHCN = "簡體中文"

enUS.LANGUAGE_ZHTW = "繁體中文"
zhCN.LANGUAGE_ZHTW = "繁体中文"
zhTW.LANGUAGE_ZHTW = "繁體中文"

-- External skin mode labels.




















enUS.MSG_LANGUAGE_CHANGED = "Language switched to: %s"
zhCN.MSG_LANGUAGE_CHANGED = "语言已切换为：%s"
zhTW.MSG_LANGUAGE_CHANGED = "語言已切換為：%s"

enUS.LABEL_DELAY_CAST_SUCCESS = "Delay playback"
zhCN.LABEL_DELAY_CAST_SUCCESS = "延时播放"
zhTW.LABEL_DELAY_CAST_SUCCESS = "延時播放"

enUS.LABEL_DELAY_SECONDS = "Delay (sec)"
zhCN.LABEL_DELAY_SECONDS = "延时（秒）"
zhTW.LABEL_DELAY_SECONDS = "延時（秒）"

enUS.MSG_INVALID_DELAY_SECONDS = "Delay playback is enabled. Please enter a delay greater than 0 seconds."
zhCN.MSG_INVALID_DELAY_SECONDS = "已启用延时播放，请填写大于 0 的延时秒数。"
zhTW.MSG_INVALID_DELAY_SECONDS = "已啟用延時播放，請填寫大於 0 的延時秒數。"

enUS.SAVED_CAST_DELAY = "Delay: %.2fs"
zhCN.SAVED_CAST_DELAY = "延时：%.2f秒"
zhTW.SAVED_CAST_DELAY = "延時：%.2f秒"



-- Popup editor architecture labels.
enUS.EDITOR_DESC = "Configure trigger scope, spell parameters, and the single voice source used by this alert."
zhCN.EDITOR_DESC = "按统一弹窗结构配置作用域、技能参数和本条语音唯一使用的来源。"
zhTW.EDITOR_DESC = "依統一彈窗結構設定作用域、技能參數與本條語音唯一使用的來源。"
enUS.EDITOR_DESC_COOLDOWN = "Enter a spell or item manually, or use Quick Skill Select (Fixed CD / Ready / On Cooldown; items use fixed CD). Quick Skill Select data comes from the Cooldown Manager; cross-spec lists need that spec logged in once."
zhCN.EDITOR_DESC_COOLDOWN = "可手动填写技能或物品，也可使用快速选择技能（技能：固定CD / 就绪 / 冷却中，物品按固定CD）。快速选择技能数据来自冷却管理器，跨专精列表需该专精登录一次后补全。"
zhTW.EDITOR_DESC_COOLDOWN = "可手動填寫技能或物品，也可使用快速選擇技能（技能：固定CD / 就緒 / 冷卻中，物品依固定CD）。快速選擇技能資料來自冷卻管理器，跨專精列表需該專精登入一次後補全。"

enUS.LABEL_CUSTOM_SOUND_PATH = "Custom Sound Path"
zhCN.LABEL_CUSTOM_SOUND_PATH = "自定义语音路径"
zhTW.LABEL_CUSTOM_SOUND_PATH = "自訂語音路徑"

enUS.LABEL_TTS_TEXT = "TTS Text"
zhCN.LABEL_TTS_TEXT = "TTS 文本"
zhTW.LABEL_TTS_TEXT = "TTS 文字"





local selected = (activeLocale == "zhCN" and zhCN) or (activeLocale == "zhTW" and zhTW) or enUS
NS.L_TABLE = selected
NS.L_ENUS = enUS

function NS.L(key, ...)
    local value = selected[key] or enUS[key] or tostring(key or "")
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

function NS.GetLanguageMode()
    return activeLanguageMode
end

function NS.GetLanguageDisplayName(mode)
    mode = NormalizeLanguageMode(mode)
    if mode == "zhCN" then
        return NS.L("LANGUAGE_ZHCN")
    elseif mode == "zhTW" then
        return NS.L("LANGUAGE_ZHTW")
    elseif mode == "enUS" then
        return NS.L("LANGUAGE_ENUS")
    end
    return NS.L("LANGUAGE_AUTO")
end

function NS.SetLanguageMode(mode)
    activeLanguageMode = NormalizeLanguageMode(mode)
    activeLocale = ResolveActiveLocale(activeLanguageMode)
    selected = (activeLocale == "zhCN" and zhCN) or (activeLocale == "zhTW" and zhTW) or enUS
    NS.LOCALE = activeLocale
    NS.L_TABLE = selected

    local db = rawget(_G, "QFXSkillAlertsDB")
    if type(db) ~= "table" then
        db = {}
        _G.QFXSkillAlertsDB = db
    end
    db.languageMode = activeLanguageMode

    -- Saved-list rows cache localized strings; drop them on language change.
    local savedListLayout = rawget(NS, "SavedListLayout")
    if savedListLayout and type(savedListLayout.ClearRowCache) == "function" then
        savedListLayout:ClearRowCache()
    end

    NS.ADDON_DISPLAY_NAME = NS.L("ADDON_DISPLAY_NAME")
    NS.ADDON_SHORT_NAME = NS.L("ADDON_SHORT_NAME")
    return activeLocale, activeLanguageMode
end

NS.ADDON_DISPLAY_NAME = NS.L("ADDON_DISPLAY_NAME")
NS.ADDON_SHORT_NAME = NS.L("ADDON_SHORT_NAME")


-- Add-alert selector and multi-channel alert editor labels.
enUS.TITLE_SELECT_ALERT_TYPE = "Select Alert Type"
zhCN.TITLE_SELECT_ALERT_TYPE = "选择新增类型"
zhTW.TITLE_SELECT_ALERT_TYPE = "選擇新增類型"
enUS.SELECT_ALERT_TYPE_DESC = "Choose the alert type to create. The editor will open after selection."
zhCN.SELECT_ALERT_TYPE_DESC = "请选择要新增的提醒类型，选择后会自动打开对应编辑界面。"
zhTW.SELECT_ALERT_TYPE_DESC = "請選擇要新增的提醒類型，選擇後會自動開啟對應編輯介面。"

enUS.SELECT_ALERT_TYPE_COOLDOWN_DESC = "Spell cooldown, item cooldown and cast-success alerts with voice / icon / text, early warning and talent / equipment filters."
zhCN.SELECT_ALERT_TYPE_COOLDOWN_DESC = "技能CD提醒、物品CD提醒，以及技能施法成功提醒；可配语音、图标、文字与提前提醒，支持天赋、装备过滤。"
zhTW.SELECT_ALERT_TYPE_COOLDOWN_DESC = "技能CD提醒、物品CD提醒，以及技能施法成功提醒；可配語音、圖示、文字與提前提醒，支援天賦、裝備過濾。"
enUS.SELECT_ALERT_TYPE_BLOODLUST_DESC = "Built-in Bloodlust / Heroism / Time Warp detection."
zhCN.SELECT_ALERT_TYPE_BLOODLUST_DESC = "内置检测嗜血、英勇、时间扭曲等团队爆发。"
zhTW.SELECT_ALERT_TYPE_BLOODLUST_DESC = "內建偵測嗜血、英勇、時間扭曲等團隊爆發。"

enUS.SECTION_BLOODLUST_BUILTIN = "Built-in Detection"
zhCN.SECTION_BLOODLUST_BUILTIN = "内置检测"
zhTW.SECTION_BLOODLUST_BUILTIN = "內建偵測"
enUS.BLOODLUST_BUILTIN_HINT = "Bloodlust, Heroism, Time Warp and similar raid burst spells are detected by the addon automatically. No spell list setup is needed here. Configure Sound, Image, and Text tabs as needed."
zhCN.BLOODLUST_BUILTIN_HINT = "嗜血、英勇、时间扭曲等团队爆发技能由插件自动内置检测，这里不需要再设置技能列表。需要提示效果时，只设置“声音 / 图片 / 文本”即可。"
zhTW.BLOODLUST_BUILTIN_HINT = "嗜血、英勇、時間扭曲等團隊爆發技能由插件自動內建偵測，這裡不需要再設定技能列表。需要提示效果時，只設定「聲音 / 圖片 / 文字」即可。"



enUS.TAB_GROUP_TYPE = "Type"
zhCN.TAB_GROUP_TYPE = "类型"
zhTW.TAB_GROUP_TYPE = "類型"
enUS.TAB_GROUP_PAGE = "Page"
zhCN.TAB_GROUP_PAGE = "页面"
zhTW.TAB_GROUP_PAGE = "頁面"
enUS.TAB_SETTINGS = "Settings"
zhCN.TAB_SETTINGS = "设置"
zhTW.TAB_SETTINGS = "設定"
enUS.SECTION_NOTIFY_CONDITIONS = "Notification Conditions"
zhCN.SECTION_NOTIFY_CONDITIONS = "通知条件"
zhTW.SECTION_NOTIFY_CONDITIONS = "通知條件"
enUS.SECTION_EVENT_NOTIFY = "Alert Actions"
zhCN.SECTION_EVENT_NOTIFY = "执行通知"
zhTW.SECTION_EVENT_NOTIFY = "執行通知"
enUS.LABEL_CONDITION_WHEN = "When"
zhCN.LABEL_CONDITION_WHEN = "当"
zhTW.LABEL_CONDITION_WHEN = "當"
enUS.LABEL_COOLDOWN_REMAINING = "cooldown remaining"
zhCN.LABEL_COOLDOWN_REMAINING = "冷却剩余时间"
zhTW.LABEL_COOLDOWN_REMAINING = "冷卻剩餘時間"
enUS.LABEL_CONDITION_EXECUTE = "Execute"
zhCN.LABEL_CONDITION_EXECUTE = "执行"
zhTW.LABEL_CONDITION_EXECUTE = "執行"
enUS.PLACEHOLDER_SELECT_ALERT_ACTIONS = "Alert actions"
zhCN.PLACEHOLDER_SELECT_ALERT_ACTIONS = "提示方式"
zhTW.PLACEHOLDER_SELECT_ALERT_ACTIONS = "提示方式"
enUS.HINT_MULTI_SELECT_ACTIONS = "Multiple actions can be selected."
zhCN.HINT_MULTI_SELECT_ACTIONS = "可多选：声音、图片、文本。"
zhTW.HINT_MULTI_SELECT_ACTIONS = "可多選：聲音、圖片、文字。"
enUS.LABEL_VOICE_CONDITION = "Voice"
zhCN.LABEL_VOICE_CONDITION = "语音"
zhTW.LABEL_VOICE_CONDITION = "語音"
enUS.LABEL_IMAGE_CONDITION = "Image"
zhCN.LABEL_IMAGE_CONDITION = "图片"
zhTW.LABEL_IMAGE_CONDITION = "圖片"
enUS.LABEL_TEXT_CONDITION = "Text"
zhCN.LABEL_TEXT_CONDITION = "文本"
zhTW.LABEL_TEXT_CONDITION = "文字"
enUS.LABEL_SKILL_CD = "Skill CD"
zhCN.LABEL_SKILL_CD = "技能CD"
zhTW.LABEL_SKILL_CD = "技能CD"
enUS.LABEL_SECONDS_SHORT = "sec"
zhCN.LABEL_SECONDS_SHORT = "秒"
zhTW.LABEL_SECONDS_SHORT = "秒"

enUS.TAB_VOICE = "Sound"
zhCN.TAB_VOICE = "声音"
zhTW.TAB_VOICE = "聲音"
enUS.TAB_IMAGE = "Image"
zhCN.TAB_IMAGE = "图片"
zhTW.TAB_IMAGE = "圖片"
enUS.TAB_TEXT = "Text"
zhCN.TAB_TEXT = "文本"
zhTW.TAB_TEXT = "文字"
enUS.LABEL_ENABLE_VOICE_ALERT = "Enable voice alert"
zhCN.LABEL_ENABLE_VOICE_ALERT = "启用语音提示"
zhTW.LABEL_ENABLE_VOICE_ALERT = "啟用語音提示"
enUS.LABEL_ENABLE_IMAGE_ALERT = "Enable image alert"
zhCN.LABEL_ENABLE_IMAGE_ALERT = "启用图片提示"
zhTW.LABEL_ENABLE_IMAGE_ALERT = "啟用圖片提示"
enUS.LABEL_ENABLE_TEXT_ALERT = "Enable text alert"
zhCN.LABEL_ENABLE_TEXT_ALERT = "启用文本提示"
zhTW.LABEL_ENABLE_TEXT_ALERT = "啟用文字提示"
enUS.LABEL_IMAGE_PATH = "Image / Icon Path"
zhCN.LABEL_IMAGE_PATH = "图片 / 图标路径"
zhTW.LABEL_IMAGE_PATH = "圖片 / 圖示路徑"
enUS.LABEL_IMAGE_SIZE = "Image Size"
zhCN.LABEL_IMAGE_SIZE = "图片大小"
zhTW.LABEL_IMAGE_SIZE = "圖片大小"
enUS.LABEL_IMAGE_STRATA = "Display Layer"
zhCN.LABEL_IMAGE_STRATA = "显示层级"
zhTW.LABEL_IMAGE_STRATA = "顯示層級"
enUS.LABEL_END_EVENTS = "End Display On"
zhCN.LABEL_END_EVENTS = "结束显示事件"
zhTW.LABEL_END_EVENTS = "結束顯示事件"
enUS.PLACEHOLDER_SELECT_END_EVENTS = "Select end events"
zhCN.PLACEHOLDER_SELECT_END_EVENTS = "选择结束事件"
zhTW.PLACEHOLDER_SELECT_END_EVENTS = "選擇結束事件"
enUS.STRATA_BACKGROUND = "Background"
zhCN.STRATA_BACKGROUND = "背景层"
zhTW.STRATA_BACKGROUND = "背景層"
enUS.STRATA_LOW = "Low"
zhCN.STRATA_LOW = "低"
zhTW.STRATA_LOW = "低"
enUS.STRATA_MEDIUM = "Medium"
zhCN.STRATA_MEDIUM = "中"
zhTW.STRATA_MEDIUM = "中"
enUS.STRATA_HIGH = "High"
zhCN.STRATA_HIGH = "高"
zhTW.STRATA_HIGH = "高"
enUS.STRATA_DIALOG = "Dialog"
zhCN.STRATA_DIALOG = "对话框"
zhTW.STRATA_DIALOG = "對話框"
enUS.STRATA_FULLSCREEN = "Fullscreen"
zhCN.STRATA_FULLSCREEN = "全屏"
zhTW.STRATA_FULLSCREEN = "全螢幕"
enUS.STRATA_FULLSCREEN_DIALOG = "Fullscreen Dialog (default)"
zhCN.STRATA_FULLSCREEN_DIALOG = "全屏对话框（默认）"
zhTW.STRATA_FULLSCREEN_DIALOG = "全螢幕對話框（預設）"
enUS.STRATA_TOOLTIP = "Tooltip (topmost)"
zhCN.STRATA_TOOLTIP = "提示层（最上层）"
zhTW.STRATA_TOOLTIP = "提示層（最上層）"
enUS.END_EVENT_PLAYER_DEAD = "Player dies"
zhCN.END_EVENT_PLAYER_DEAD = "玩家死亡"
zhTW.END_EVENT_PLAYER_DEAD = "玩家死亡"
enUS.END_EVENT_PLAYER_ALIVE = "Player alive (accept rez)"
zhCN.END_EVENT_PLAYER_ALIVE = "玩家复活（接受复活）"
zhTW.END_EVENT_PLAYER_ALIVE = "玩家復活（接受復活）"
enUS.END_EVENT_PLAYER_UNGHOST = "Player alive (corpse run)"
zhCN.END_EVENT_PLAYER_UNGHOST = "玩家跑尸复活"
zhTW.END_EVENT_PLAYER_UNGHOST = "玩家跑魂復活"
enUS.END_EVENT_PLAYER_REGEN_DISABLED = "Enter combat"
zhCN.END_EVENT_PLAYER_REGEN_DISABLED = "进入战斗"
zhTW.END_EVENT_PLAYER_REGEN_DISABLED = "進入戰鬥"
enUS.END_EVENT_PLAYER_REGEN_ENABLED = "Leave combat"
zhCN.END_EVENT_PLAYER_REGEN_ENABLED = "离开战斗"
zhTW.END_EVENT_PLAYER_REGEN_ENABLED = "離開戰鬥"
enUS.END_EVENT_PLAYER_TARGET_CHANGED = "Change target"
zhCN.END_EVENT_PLAYER_TARGET_CHANGED = "切换目标"
zhTW.END_EVENT_PLAYER_TARGET_CHANGED = "切換目標"
enUS.END_EVENT_PLAYER_FOCUS_CHANGED = "Change focus"
zhCN.END_EVENT_PLAYER_FOCUS_CHANGED = "切换焦点"
zhTW.END_EVENT_PLAYER_FOCUS_CHANGED = "切換焦點"
enUS.END_EVENT_PLAYER_STARTED_MOVING = "Start moving"
zhCN.END_EVENT_PLAYER_STARTED_MOVING = "开始移动"
zhTW.END_EVENT_PLAYER_STARTED_MOVING = "開始移動"
enUS.END_EVENT_PLAYER_STOPPED_MOVING = "Stop moving"
zhCN.END_EVENT_PLAYER_STOPPED_MOVING = "停止移动"
zhTW.END_EVENT_PLAYER_STOPPED_MOVING = "停止移動"
enUS.END_EVENT_PLAYER_ENTERING_WORLD = "Entering world / loading"
zhCN.END_EVENT_PLAYER_ENTERING_WORLD = "进入世界 / 过图"
zhTW.END_EVENT_PLAYER_ENTERING_WORLD = "進入世界 / 過圖"
enUS.END_EVENT_ZONE_CHANGED_NEW_AREA = "Change zone"
zhCN.END_EVENT_ZONE_CHANGED_NEW_AREA = "切换区域"
zhTW.END_EVENT_ZONE_CHANGED_NEW_AREA = "切換區域"
enUS.END_EVENT_PLAYER_SPECIALIZATION_CHANGED = "Change specialization"
zhCN.END_EVENT_PLAYER_SPECIALIZATION_CHANGED = "切换专精"
zhTW.END_EVENT_PLAYER_SPECIALIZATION_CHANGED = "切換專精"
enUS.END_EVENT_PLAYER_MOUNT_DISPLAY_CHANGED = "Mount changed"
zhCN.END_EVENT_PLAYER_MOUNT_DISPLAY_CHANGED = "坐骑变化"
zhTW.END_EVENT_PLAYER_MOUNT_DISPLAY_CHANGED = "坐騎變化"
enUS.END_EVENT_ENCOUNTER_START = "Encounter start"
zhCN.END_EVENT_ENCOUNTER_START = "首领战开始"
zhTW.END_EVENT_ENCOUNTER_START = "首領戰開始"
enUS.END_EVENT_ENCOUNTER_END = "Encounter end"
zhCN.END_EVENT_ENCOUNTER_END = "首领战结束"
zhTW.END_EVENT_ENCOUNTER_END = "首領戰結束"
enUS.END_EVENT_PLAYER_LEVEL_UP = "Level up"
zhCN.END_EVENT_PLAYER_LEVEL_UP = "升级"
zhTW.END_EVENT_PLAYER_LEVEL_UP = "升級"



enUS.LABEL_TEXT_CONTENT = "Alert Text"
zhCN.LABEL_TEXT_CONTENT = "提示文本"
zhTW.LABEL_TEXT_CONTENT = "提示文字"
enUS.LABEL_TEXT_SIZE = "Text Size"
zhCN.LABEL_TEXT_SIZE = "文字大小"
zhTW.LABEL_TEXT_SIZE = "文字大小"



enUS.LABEL_POSITION_X = "X Offset"
zhCN.LABEL_POSITION_X = "X位置"
zhTW.LABEL_POSITION_X = "X位置"
enUS.LABEL_POSITION_Y = "Y Offset"
zhCN.LABEL_POSITION_Y = "Y位置"
zhTW.LABEL_POSITION_Y = "Y位置"









enUS.MSG_BLOODLUST_SUMMARY = "Bloodlust alert can now use voice source, image, and text settings."
zhCN.MSG_BLOODLUST_SUMMARY = "嗜血提示现在可使用语音来源、图片和文本设置。"
zhTW.MSG_BLOODLUST_SUMMARY = "嗜血提示現在可使用語音來源、圖片與文字設定。"

-- QFX visual alert layout additions.
enUS.LABEL_IMAGE_SOURCE = "Image Source"
zhCN.LABEL_IMAGE_SOURCE = "图片来源"
zhTW.LABEL_IMAGE_SOURCE = "圖片來源"
enUS.IMAGE_SOURCE_AUTO = "Auto: spell/item icon"
zhCN.IMAGE_SOURCE_AUTO = "自动使用技能/物品图标"
zhTW.IMAGE_SOURCE_AUTO = "自動使用技能/物品圖示"
enUS.IMAGE_SOURCE_SPELL = "Spell ID icon"
zhCN.IMAGE_SOURCE_SPELL = "技能ID获取图标"
zhTW.IMAGE_SOURCE_SPELL = "技能ID取得圖示"
enUS.IMAGE_SOURCE_ITEM = "Item ID icon"
zhCN.IMAGE_SOURCE_ITEM = "物品ID获取图标"
zhTW.IMAGE_SOURCE_ITEM = "物品ID取得圖示"
enUS.IMAGE_SOURCE_ICON = "Icon FileID"
zhCN.IMAGE_SOURCE_ICON = "手动填写图标ID"
zhTW.IMAGE_SOURCE_ICON = "手動填寫圖示ID"
enUS.IMAGE_SOURCE_PATH = "Custom path"
zhCN.IMAGE_SOURCE_PATH = "自定义图片路径"
zhTW.IMAGE_SOURCE_PATH = "自訂圖片路徑"
enUS.IMAGE_SOURCE_SHAREDMEDIA = "Shared media image"
zhCN.IMAGE_SOURCE_SHAREDMEDIA = "共享图片（SharedMedia）"
zhTW.IMAGE_SOURCE_SHAREDMEDIA = "共享圖片（SharedMedia）"
enUS.LABEL_IMAGE_SHAREDMEDIA = "Shared Image"
zhCN.LABEL_IMAGE_SHAREDMEDIA = "共享图片"
zhTW.LABEL_IMAGE_SHAREDMEDIA = "共享圖片"
enUS.PLACEHOLDER_SELECT_SHAREDMEDIA_IMAGE = "Select a shared image"
zhCN.PLACEHOLDER_SELECT_SHAREDMEDIA_IMAGE = "选择共享图片"
zhTW.PLACEHOLDER_SELECT_SHAREDMEDIA_IMAGE = "選擇共享圖片"
enUS.LABEL_IMAGE_ICON_ID = "Icon FileID"
zhCN.LABEL_IMAGE_ICON_ID = "图标ID"
zhTW.LABEL_IMAGE_ICON_ID = "圖示ID"
enUS.LABEL_IMAGE_SPELL_ID = "Spell ID"
zhCN.LABEL_IMAGE_SPELL_ID = "技能ID"
zhTW.LABEL_IMAGE_SPELL_ID = "技能ID"
enUS.LABEL_IMAGE_ITEM_ID = "Item ID"
zhCN.LABEL_IMAGE_ITEM_ID = "物品ID"
zhTW.LABEL_IMAGE_ITEM_ID = "物品ID"
enUS.LABEL_LIMIT_IMAGE_DURATION = "Limit image duration"
zhCN.LABEL_LIMIT_IMAGE_DURATION = "限制图片显示时间"
zhTW.LABEL_LIMIT_IMAGE_DURATION = "限制圖片顯示時間"
enUS.LABEL_LIMIT_TEXT_DURATION = "Limit text duration"
zhCN.LABEL_LIMIT_TEXT_DURATION = "限制文本显示时间"
zhTW.LABEL_LIMIT_TEXT_DURATION = "限制文字顯示時間"
enUS.LABEL_IMAGE_POSITION = "Image position"
zhCN.LABEL_IMAGE_POSITION = "图片位置"
zhTW.LABEL_IMAGE_POSITION = "圖片位置"
enUS.LABEL_TEXT_POSITION = "Text position"
zhCN.LABEL_TEXT_POSITION = "文本位置"
zhTW.LABEL_TEXT_POSITION = "文字位置"
enUS.LABEL_TEXT_POSITION_NUDGE = "Text position fine tune"
zhCN.LABEL_TEXT_POSITION_NUDGE = "文本位置微调"
zhTW.LABEL_TEXT_POSITION_NUDGE = "文字位置微調"



enUS.BTN_SHOW_PREVIEW = "Show all previews"
zhCN.BTN_SHOW_PREVIEW = "显示全部预览"
zhTW.BTN_SHOW_PREVIEW = "顯示全部預覽"
enUS.BTN_HIDE_PREVIEW = "Hide all previews"
zhCN.BTN_HIDE_PREVIEW = "隐藏全部预览"
zhTW.BTN_HIDE_PREVIEW = "隱藏全部預覽"
enUS.BTN_RESET = "Reset"
zhCN.BTN_RESET = "重置"
zhTW.BTN_RESET = "重置"
enUS.LABEL_IMAGE_NUDGE = "Image position fine tune"
zhCN.LABEL_IMAGE_NUDGE = "图片位置微调"
zhTW.LABEL_IMAGE_NUDGE = "圖片位置微調"
enUS.LABEL_TEXT_LAYOUT = "Text + image layout"
zhCN.LABEL_TEXT_LAYOUT = "图文组合布局"
zhTW.LABEL_TEXT_LAYOUT = "圖文組合佈局"
enUS.LABEL_TEXT_ATTACH_MODE = "Text position"
zhCN.LABEL_TEXT_ATTACH_MODE = "文本位置"
zhTW.LABEL_TEXT_ATTACH_MODE = "文字位置"
enUS.TEXT_ATTACH_OUTSIDE = "Outside image"
zhCN.TEXT_ATTACH_OUTSIDE = "图外"
zhTW.TEXT_ATTACH_OUTSIDE = "圖外"
enUS.TEXT_ATTACH_INSIDE = "Inside image"
zhCN.TEXT_ATTACH_INSIDE = "图内"
zhTW.TEXT_ATTACH_INSIDE = "圖內"
enUS.LABEL_TEXT_VALIGN = "Vertical align"
zhCN.LABEL_TEXT_VALIGN = "上下对齐"
zhTW.LABEL_TEXT_VALIGN = "上下對齊"
enUS.TEXT_VALIGN_TOP = "Top"
zhCN.TEXT_VALIGN_TOP = "上对齐"
zhTW.TEXT_VALIGN_TOP = "上對齊"
enUS.TEXT_VALIGN_MIDDLE = "Middle"
zhCN.TEXT_VALIGN_MIDDLE = "居中"
zhTW.TEXT_VALIGN_MIDDLE = "置中"
enUS.TEXT_VALIGN_BOTTOM = "Bottom"
zhCN.TEXT_VALIGN_BOTTOM = "下对齐"
zhTW.TEXT_VALIGN_BOTTOM = "下對齊"
enUS.LABEL_TEXT_HALIGN = "Horizontal align"
zhCN.LABEL_TEXT_HALIGN = "左右对齐"
zhTW.LABEL_TEXT_HALIGN = "左右對齊"
enUS.TEXT_HALIGN_LEFT = "Left"
zhCN.TEXT_HALIGN_LEFT = "左对齐"
zhTW.TEXT_HALIGN_LEFT = "左對齊"
enUS.TEXT_HALIGN_CENTER = "Center"
zhCN.TEXT_HALIGN_CENTER = "居中"
zhTW.TEXT_HALIGN_CENTER = "置中"
enUS.TEXT_HALIGN_RIGHT = "Right"
zhCN.TEXT_HALIGN_RIGHT = "右对齐"
zhTW.TEXT_HALIGN_RIGHT = "右對齊"
enUS.LABEL_TEXT_NUDGE = "Text fine tune"
zhCN.LABEL_TEXT_NUDGE = "文本微调"
zhTW.LABEL_TEXT_NUDGE = "文字微調"










-- 1.0.156 cast-success notification condition UI.
enUS.LABEL_CAST_DELAY_FIXED = "Delay"
zhCN.LABEL_CAST_DELAY_FIXED = "延时"
zhTW.LABEL_CAST_DELAY_FIXED = "延時"
enUS.LABEL_CAST_DELAY_AFTER_EXECUTE = "sec"
zhCN.LABEL_CAST_DELAY_AFTER_EXECUTE = "秒后"
zhTW.LABEL_CAST_DELAY_AFTER_EXECUTE = "秒後"
enUS.CAST_DELAY_MODE_SHOW = "Show"
zhCN.CAST_DELAY_MODE_SHOW = "显示"
zhTW.CAST_DELAY_MODE_SHOW = "顯示"




-- 1.0.158 cast-success execution mode UI.
enUS.LABEL_CAST_IMMEDIATE_EXECUTE = "Execute immediately"
zhCN.LABEL_CAST_IMMEDIATE_EXECUTE = "立即执行"
zhTW.LABEL_CAST_IMMEDIATE_EXECUTE = "立即執行"
enUS.LABEL_CAST_DELAY_EXECUTE = "Delay execute"
zhCN.LABEL_CAST_DELAY_EXECUTE = "延时执行"
zhTW.LABEL_CAST_DELAY_EXECUTE = "延時執行"

-- Custom alert type.
enUS.TAB_CUSTOM = "Custom"
zhCN.TAB_CUSTOM = "自定义"
zhTW.TAB_CUSTOM = "自訂"
enUS.ENTRY_TYPE_CUSTOM = "Custom"
zhCN.ENTRY_TYPE_CUSTOM = "自定义"
zhTW.ENTRY_TYPE_CUSTOM = "自訂"



enUS.SECTION_CUSTOM_CODE = "Custom Trigger"
zhCN.SECTION_CUSTOM_CODE = "自定义触发"
zhTW.SECTION_CUSTOM_CODE = "自訂觸發"



enUS.SECTION_CUSTOM_EXECUTE_NOTIFY = "Execution & Notification"
zhCN.SECTION_CUSTOM_EXECUTE_NOTIFY = "执行通知"
zhTW.SECTION_CUSTOM_EXECUTE_NOTIFY = "執行通知"
enUS.LABEL_CUSTOM_NAME = "Custom Name"
zhCN.LABEL_CUSTOM_NAME = "自定义名称"
zhTW.LABEL_CUSTOM_NAME = "自訂名稱"
enUS.LABEL_CUSTOM_EVENT_TRIGGER = "Event trigger"
zhCN.LABEL_CUSTOM_EVENT_TRIGGER = "事件触发"
zhTW.LABEL_CUSTOM_EVENT_TRIGGER = "事件觸發"
enUS.LABEL_CUSTOM_EVENTS = "Events"
zhCN.LABEL_CUSTOM_EVENTS = "事件"
zhTW.LABEL_CUSTOM_EVENTS = "事件"
enUS.PLACEHOLDER_SELECT_EVENTS = "Select events"
zhCN.PLACEHOLDER_SELECT_EVENTS = "选择事件"
zhTW.PLACEHOLDER_SELECT_EVENTS = "選擇事件"
enUS.LABEL_CUSTOM_EVENT_TEXT = "Custom events (comma or space separated)"
zhCN.LABEL_CUSTOM_EVENT_TEXT = "自定义事件（逗号或空格分隔）"
zhTW.LABEL_CUSTOM_EVENT_TEXT = "自訂事件（逗號或空格分隔）"
enUS.LABEL_CUSTOM_TICKER_TRIGGER = "Periodic execution"
zhCN.LABEL_CUSTOM_TICKER_TRIGGER = "周期执行"
zhTW.LABEL_CUSTOM_TICKER_TRIGGER = "週期執行"
enUS.LABEL_CUSTOM_INTERVAL = "Interval"
zhCN.LABEL_CUSTOM_INTERVAL = "间隔"
zhTW.LABEL_CUSTOM_INTERVAL = "間隔"
enUS.LABEL_CUSTOM_CODE = "Custom Lua Code"
zhCN.LABEL_CUSTOM_CODE = "自定义 Lua 代码"
zhTW.LABEL_CUSTOM_CODE = "自訂 Lua 程式碼"
enUS.BTN_CUSTOM_TEST = "Run and Extract Variables"
zhCN.BTN_CUSTOM_TEST = "执行并提取变量"
zhTW.BTN_CUSTOM_TEST = "執行並提取變數"
enUS.LABEL_CUSTOM_RESULT_VAR = "Variable"
zhCN.LABEL_CUSTOM_RESULT_VAR = "变量"
zhTW.LABEL_CUSTOM_RESULT_VAR = "變數"
enUS.LABEL_CUSTOM_COMPARE_VALUE = "Value / Expr"
zhCN.LABEL_CUSTOM_COMPARE_VALUE = "值/表达式"
zhTW.LABEL_CUSTOM_COMPARE_VALUE = "值/表達式"



enUS.LABEL_CUSTOM_NOTIFY_N = "Condition %d"
zhCN.LABEL_CUSTOM_NOTIFY_N = "条件%d"
zhTW.LABEL_CUSTOM_NOTIFY_N = "條件%d"
enUS.LABEL_CUSTOM_CONDITION_LOGIC = "Condition Logic"
zhCN.LABEL_CUSTOM_CONDITION_LOGIC = "条件关系"
zhTW.LABEL_CUSTOM_CONDITION_LOGIC = "條件關係"
enUS.CUSTOM_CONDITION_OR = "Any condition"
zhCN.CUSTOM_CONDITION_OR = "或者：任意满足"
zhTW.CUSTOM_CONDITION_OR = "或者：任一滿足"
enUS.CUSTOM_CONDITION_AND = "All conditions"
zhCN.CUSTOM_CONDITION_AND = "并且：全部满足"
zhTW.CUSTOM_CONDITION_AND = "並且：全部滿足"
enUS.PLACEHOLDER_SELECT_VARIABLE = "Select variable"
zhCN.PLACEHOLDER_SELECT_VARIABLE = "选择变量"
zhTW.PLACEHOLDER_SELECT_VARIABLE = "選擇變數"









enUS.MSG_CUSTOM_TEST_OK = "Custom code returned %d variables."
zhCN.MSG_CUSTOM_TEST_OK = "自定义代码返回了 %d 个变量。"
zhTW.MSG_CUSTOM_TEST_OK = "自訂程式碼返回了 %d 個變數。"
enUS.MSG_CUSTOM_TEST_FAILED = "Custom code failed: %s"
zhCN.MSG_CUSTOM_TEST_FAILED = "自定义代码执行失败：%s"
zhTW.MSG_CUSTOM_TEST_FAILED = "自訂程式碼執行失敗：%s"

-- Blizzard Cooldown Manager voice editor.
enUS.CDM_VOICE = "Cooldown Manager Voice"
enUS.CDM_VOICE_DESC = "Quickly edit Cooldown Manager voice alerts; each ability can use a different voice per event. Alerts follow Blizzard's trigger and may be slightly delayed."
enUS.CDM_VOICE_EDITOR_DESC = "Cooldown Manager voices may be slightly delayed. For simple ready/available alerts use CD Alert; for charge gained and buff applied/removed alerts keep using Cooldown Manager Voice."
enUS.CDM_VOICE_EDITOR_TITLE = "Cooldown Manager Voice"
enUS.CDM_CURRENT_CLASS = "Current class:"
enUS.CDM_CURRENT_SPEC = "Current spec:"
enUS.CDM_CATEGORY = "Cooldown Manager category:"
enUS.CDM_CATEGORY_ESSENTIAL = "Essential Cooldowns"
enUS.CDM_CATEGORY_UTILITY = "Utility Cooldowns"
enUS.CDM_CATEGORY_TRACKED_BUFF = "Tracked Buffs"
enUS.CDM_CATEGORY_TRACKED_BAR = "Tracked Bars"
enUS.CDM_SKILL = "Ability"
enUS.CDM_EVENT = "Event"
enUS.CDM_CUSTOM_VOICE = "Custom Voice"
enUS.CDM_ACTION = "Action"
enUS.CDM_TEST = "Test"

enUS.CDM_DELETED = "Cooldown Manager voice deleted."
enUS.CDM_NOT_AVAILABLE = "Cooldown Manager is not available."
enUS.CDM_DATA_NOT_READY = "Cooldown Manager data is not ready."
enUS.CDM_CATEGORY_EMPTY = "No loaded abilities are shown in this category."
enUS.CDM_EVENT_SOUND_UNSUPPORTED = "This action does not support a sound alert."
enUS.CDM_SELECT_VOICE = "No voice selected"
enUS.CDM_MISSING_VOICE = "Missing voice"
enUS.CDM_PLAY_FAILED = "Could not play the Cooldown Manager voice: %s (check that the file exists and is a supported .ogg or .mp3)"
enUS.CDM_CLEANUP_NONE = "No addon voices need to be removed from the Cooldown Manager."
enUS.CDM_CLEANUP_DONE = "Removed %d addon voice alert(s) from the Cooldown Manager. The UI will reload; these events are played by the addon now."
enUS.CDM_CLEANUP_FAILED = "Failed to clean up the Cooldown Manager voices."
enUS.CDM_CLEANUP_PROMPT = "%d legacy Cooldown Manager voice alert(s) were found. Clean them up now? The UI will reload once."
enUS.CDM_CLEANUP_APPLY = "Clean Up and Reload"
enUS.CDM_NATIVE_SOUND_WILL_REPLACE = "Replaces existing sound"

enUS.CDM_ALERT_LIMIT_REACHED = "This ability has reached the Cooldown Manager alert limit. Remove an unneeded alert first."
enUS.CDM_COMBAT_BLOCKED = "Cooldown Manager settings cannot be changed during combat or while the current content is restricted."
enUS.CDM_SPEC_CHANGED = "The specialization changed; the content has been refreshed."
enUS.CDM_DELETE_CONFIRM = "Delete the Cooldown Manager voice for “%s - %s - %s”?\n\nThe change will be removed from Cooldown Manager immediately."
enUS.CDM_DELETE_FAILED = "Failed to delete the Cooldown Manager voice."
enUS.CDM_SAVE_FAILED = "Failed to save the Cooldown Manager voice."
enUS.CDM_ENTRY_TYPE = "Cooldown Manager Voice"
enUS.CDM_UNKNOWN_SKILL = "Unknown ability (Cooldown ID: %d)"
enUS.CDM_EVENT_FALLBACK = "Event %d"

zhCN.CDM_VOICE = "冷却管理器语音"
zhCN.CDM_VOICE_DESC = "快速编辑冷却管理器的技能语音；同一技能可分别为各操作类型配置语音，提醒随暴雪预警触发，可能有少许延迟。"
zhCN.CDM_VOICE_EDITOR_DESC = "冷却管理器语音可能有少许延迟：只提示技能是否可用，请用“CD提示”；获得充能、增益的显示或消失提示，仍用冷却管理器语音。"
zhCN.CDM_VOICE_EDITOR_TITLE = "冷却管理器语音"
zhCN.CDM_CURRENT_CLASS = "当前职业："
zhCN.CDM_CURRENT_SPEC = "当前专精："
zhCN.CDM_CATEGORY = "冷却管理器分类："
zhCN.CDM_CATEGORY_ESSENTIAL = "重要技能冷却"
zhCN.CDM_CATEGORY_UTILITY = "效能技能冷却"
zhCN.CDM_CATEGORY_TRACKED_BUFF = "追踪的增益效果"
zhCN.CDM_CATEGORY_TRACKED_BAR = "追踪的状态栏"
zhCN.CDM_SKILL = "技能"
zhCN.CDM_EVENT = "操作类型"
zhCN.CDM_CUSTOM_VOICE = "自定义语音"
zhCN.CDM_ACTION = "操作"
zhCN.CDM_TEST = "试听"

zhCN.CDM_DELETED = "冷却管理器语音已删除。"
zhCN.CDM_NOT_AVAILABLE = "冷却管理器不可用。"
zhCN.CDM_DATA_NOT_READY = "冷却管理器数据尚未加载完成。"
zhCN.CDM_CATEGORY_EMPTY = "当前分类没有已载入的技能。"
zhCN.CDM_EVENT_SOUND_UNSUPPORTED = "该操作不支持声音警报。"
zhCN.CDM_SELECT_VOICE = "未选择自定义语音"
zhCN.CDM_MISSING_VOICE = "缺失语音"
zhCN.CDM_PLAY_FAILED = "无法播放冷却管理器语音：%s（请检查文件是否存在、是否为支持的 .ogg 或 .mp3）"
zhCN.CDM_CLEANUP_NONE = "冷却管理器中没有需要清理的插件语音。"
zhCN.CDM_CLEANUP_DONE = "已从冷却管理器移除 %d 条插件语音警报。界面即将重载；这些事件现在由插件播放。"
zhCN.CDM_CLEANUP_FAILED = "清理冷却管理器语音失败。"
zhCN.CDM_CLEANUP_PROMPT = "检测到 %d 条旧版冷却管理器语音残留，是否现在清理？清理后将重载一次界面。"
zhCN.CDM_CLEANUP_APPLY = "清理并重载"
zhCN.CDM_NATIVE_SOUND_WILL_REPLACE = "该操作已有系统声音，应用后将替换。"

zhCN.CDM_ALERT_LIMIT_REACHED = "该技能的冷却管理器警报数量已达到上限，请先删除不需要的警报。"
zhCN.CDM_COMBAT_BLOCKED = "战斗中或当前内容受限时无法修改冷却管理器配置，请在安全状态下重试。"
zhCN.CDM_SPEC_CHANGED = "专精已变化，内容已刷新。"
zhCN.CDM_DELETE_CONFIRM = "确定删除“%s－%s－%s”的冷却管理器语音吗？\n\n该语音将立即从冷却管理器中移除。"
zhCN.CDM_DELETE_FAILED = "冷却管理器语音删除失败。"
zhCN.CDM_SAVE_FAILED = "冷却管理器语音保存失败。"
zhCN.CDM_ENTRY_TYPE = "冷却管理器语音"
zhCN.CDM_UNKNOWN_SKILL = "未知技能（Cooldown ID: %d）"
zhCN.CDM_EVENT_FALLBACK = "事件 %d"

zhTW.CDM_VOICE = "冷卻管理器語音"
zhTW.CDM_VOICE_DESC = "快速編輯冷卻管理器的技能語音；同一技能可分別為各操作類型設定語音，提醒隨暴雪預警觸發，可能略有延遲。"
zhTW.CDM_VOICE_EDITOR_DESC = "冷卻管理器語音可能略有延遲：僅提示技能是否可用，請用「CD提示」；獲得充能、增益顯示或消失提示，仍請使用冷卻管理器語音。"
zhTW.CDM_VOICE_EDITOR_TITLE = "冷卻管理器語音"
zhTW.CDM_CURRENT_CLASS = "目前職業："
zhTW.CDM_CURRENT_SPEC = "目前專精："
zhTW.CDM_CATEGORY = "冷卻管理器分類："
zhTW.CDM_CATEGORY_ESSENTIAL = "重要技能冷卻"
zhTW.CDM_CATEGORY_UTILITY = "效能技能冷卻"
zhTW.CDM_CATEGORY_TRACKED_BUFF = "追蹤的增益效果"
zhTW.CDM_CATEGORY_TRACKED_BAR = "追蹤的狀態列"
zhTW.CDM_SKILL = "技能"
zhTW.CDM_EVENT = "操作類型"
zhTW.CDM_CUSTOM_VOICE = "自訂語音"
zhTW.CDM_ACTION = "操作"
zhTW.CDM_TEST = "試聽"

zhTW.CDM_DELETED = "冷卻管理器語音已刪除。"
zhTW.CDM_NOT_AVAILABLE = "冷卻管理器無法使用。"
zhTW.CDM_DATA_NOT_READY = "冷卻管理器資料尚未載入完成。"
zhTW.CDM_CATEGORY_EMPTY = "目前分類沒有已載入的技能。"
zhTW.CDM_EVENT_SOUND_UNSUPPORTED = "此操作不支援聲音警報。"
zhTW.CDM_SELECT_VOICE = "未選擇自訂語音"
zhTW.CDM_MISSING_VOICE = "缺少語音"
zhTW.CDM_PLAY_FAILED = "無法播放冷卻管理器語音：%s（請檢查檔案是否存在、是否為支援的 .ogg 或 .mp3）"
zhTW.CDM_CLEANUP_NONE = "冷卻管理器中沒有需要清理的插件語音。"
zhTW.CDM_CLEANUP_DONE = "已從冷卻管理器移除 %d 條插件語音警報。介面即將重新載入；這些事件現在由插件播放。"
zhTW.CDM_CLEANUP_FAILED = "清理冷卻管理器語音失敗。"
zhTW.CDM_CLEANUP_PROMPT = "偵測到 %d 條舊版冷卻管理器語音殘留，是否現在清理？清理後將重新載入一次介面。"
zhTW.CDM_CLEANUP_APPLY = "清理並重新載入"
zhTW.CDM_NATIVE_SOUND_WILL_REPLACE = "此操作已有系統聲音，套用後將取代。"

zhTW.CDM_ALERT_LIMIT_REACHED = "此技能的冷卻管理器警報數量已達上限，請先刪除不需要的警報。"
zhTW.CDM_COMBAT_BLOCKED = "戰鬥中或當前內容受限時無法修改冷卻管理器設定，請在安全狀態下重試。"
zhTW.CDM_SPEC_CHANGED = "專精已變更，內容已重新整理。"
zhTW.CDM_DELETE_CONFIRM = "確定刪除「%s－%s－%s」的冷卻管理器語音嗎？\n\n該語音將立即從冷卻管理器中移除。"
zhTW.CDM_DELETE_FAILED = "冷卻管理器語音刪除失敗。"
zhTW.CDM_SAVE_FAILED = "冷卻管理器語音儲存失敗。"
zhTW.CDM_ENTRY_TYPE = "冷卻管理器語音"
zhTW.CDM_UNKNOWN_SKILL = "未知技能（Cooldown ID: %d）"
zhTW.CDM_EVENT_FALLBACK = "事件 %d"

enUS.SEARCH_SHAREDMEDIA_SOUND = "Search SharedMedia voices..."
zhCN.SEARCH_SHAREDMEDIA_SOUND = "搜索共享语音……"
zhTW.SEARCH_SHAREDMEDIA_SOUND = "搜尋共享語音……"
enUS.SEARCH_SHAREDMEDIA_IMAGE = "Search shared images..."
zhCN.SEARCH_SHAREDMEDIA_IMAGE = "搜索共享图片……"
zhTW.SEARCH_SHAREDMEDIA_IMAGE = "搜尋共享圖片……"
enUS.SEARCH_NO_RESULTS = "No matching voice found"
zhCN.SEARCH_NO_RESULTS = "未找到匹配的语音"
zhTW.SEARCH_NO_RESULTS = "找不到符合的語音"
enUS.CDM_SEARCH_VOICE = "Search custom voices..."
zhCN.CDM_SEARCH_VOICE = "搜索自定义语音……"
zhTW.CDM_SEARCH_VOICE = "搜尋自訂語音……"



enUS.CDM_EXPORT_PRESETS = "Export CDM Presets"
zhCN.CDM_EXPORT_PRESETS = "导出冷却语音预设"
zhTW.CDM_EXPORT_PRESETS = "匯出冷卻語音預設"
enUS.CDM_PRESET_EXPORT_TITLE = "Cooldown Manager Voice Presets"
zhCN.CDM_PRESET_EXPORT_TITLE = "冷却管理器语音预设"
zhTW.CDM_PRESET_EXPORT_TITLE = "冷卻管理器語音預設"


















enUS.CDM_STATUS_SKILL_MISSING = "Ability not loaded in Cooldown Manager"
zhCN.CDM_STATUS_SKILL_MISSING = "CDM未载入技能"
zhTW.CDM_STATUS_SKILL_MISSING = "CDM未載入技能"
enUS.CDM_STATUS_SCOPE_UNLOADED = "Specialization not currently loaded"
zhCN.CDM_STATUS_SCOPE_UNLOADED = "对应专精当前未载入"
zhTW.CDM_STATUS_SCOPE_UNLOADED = "對應專精目前未載入"
enUS.CDM_STATUS_EVENT_UNSUPPORTED = "Action unsupported"
zhCN.CDM_STATUS_EVENT_UNSUPPORTED = "操作不支持"
zhTW.CDM_STATUS_EVENT_UNSUPPORTED = "操作不支援"
enUS.CDM_STATUS_VOICE_MISSING = "Voice missing"
zhCN.CDM_STATUS_VOICE_MISSING = "语音缺失"
zhTW.CDM_STATUS_VOICE_MISSING = "語音缺失"
enUS.CDM_STATUS_AMBIGUOUS_SKILL = "Ability match is ambiguous"
zhCN.CDM_STATUS_AMBIGUOUS_SKILL = "技能匹配不明确"
zhTW.CDM_STATUS_AMBIGUOUS_SKILL = "技能匹配不明確"
enUS.CDM_EXPORT_SINGLE_TITLE = "Cooldown Manager Voice Preset"
zhCN.CDM_EXPORT_SINGLE_TITLE = "冷却管理器语音单条预设"
zhTW.CDM_EXPORT_SINGLE_TITLE = "冷卻管理器語音單條預設"
enUS.CDM_EDIT_SKILL_NOT_LOADED = "The Cooldown Manager has not loaded this ability, so it cannot currently be located in the ability list."
zhCN.CDM_EDIT_SKILL_NOT_LOADED = "当前冷却管理器未载入该技能，暂时无法在技能列表中定位。"
zhTW.CDM_EDIT_SKILL_NOT_LOADED = "目前冷卻管理器未載入該技能，暫時無法在技能清單中定位。"



enUS.CDM_SAVE = "Save"
zhCN.CDM_SAVE = "保存"
zhTW.CDM_SAVE = "儲存"































enUS.CDM_SAVE_PENDING = "Saved; waiting to apply."
zhCN.CDM_SAVE_PENDING = "已保存，等待应用。"
zhTW.CDM_SAVE_PENDING = "已儲存，等待套用。"
enUS.CDM_SAVE_ALREADY_APPLIED = "Saved; the current setting is already applied."
zhCN.CDM_SAVE_ALREADY_APPLIED = "已保存，当前设置已经应用。"
zhTW.CDM_SAVE_ALREADY_APPLIED = "已儲存，目前設定已經套用。"
enUS.CDM_SAVE_TOOLTIP = "Save only to the addon; you can apply it later."
zhCN.CDM_SAVE_TOOLTIP = "仅保存到插件，稍后可统一应用。"
zhTW.CDM_SAVE_TOOLTIP = "僅儲存到插件，稍後可統一套用。"
enUS.CDM_APPLY = "Apply"
zhCN.CDM_APPLY = "应用"
zhTW.CDM_APPLY = "套用"
enUS.CDM_APPLY_TOOLTIP = "Save the current setting and write it to Cooldown Manager. The UI will reload once afterward."
zhCN.CDM_APPLY_TOOLTIP = "保存当前设置并写入冷却管理器，完成后将重载一次界面。"
zhTW.CDM_APPLY_TOOLTIP = "儲存目前設定並寫入冷卻管理器，完成後將重新載入一次介面。"
enUS.CDM_APPLY_ALL_RELOAD = "Apply All and Reload"
zhCN.CDM_APPLY_ALL_RELOAD = "应用全部并重载"
zhTW.CDM_APPLY_ALL_RELOAD = "全部套用並重新載入"
enUS.CDM_APPLY_ALL_RELOAD_COUNT = "Apply All and Reload (%d)"
zhCN.CDM_APPLY_ALL_RELOAD_COUNT = "应用全部并重载（%d）"
zhTW.CDM_APPLY_ALL_RELOAD_COUNT = "全部套用並重新載入（%d）"
enUS.CDM_APPLY_NONE = "There are no pending changes for the current specialization."
zhCN.CDM_APPLY_NONE = "当前专精没有待应用的更改。"
zhTW.CDM_APPLY_NONE = "目前專精沒有等待套用的變更。"
enUS.CDM_APPLY_AND_RELOAD = "Apply and Reload"
zhCN.CDM_APPLY_AND_RELOAD = "应用并重载"
zhTW.CDM_APPLY_AND_RELOAD = "套用並重新載入"
enUS.CDM_APPLY_LATER = "Later"
zhCN.CDM_APPLY_LATER = "稍后"
zhTW.CDM_APPLY_LATER = "稍後"
enUS.CDM_IMPORT_PENDING_CONFIRM = "Import complete.\n\nThe current specialization has %d Cooldown Manager voice settings waiting to apply. The UI will reload once after applying."
zhCN.CDM_IMPORT_PENDING_CONFIRM = "导入完成。\n\n检测到当前专精有 %d 条冷却管理器语音设置等待应用。应用完成后将重载一次界面。"
zhTW.CDM_IMPORT_PENDING_CONFIRM = "匯入完成。\n\n偵測到目前專精有 %d 條冷卻管理器語音設定等待套用。套用完成後將重新載入一次介面。"
enUS.CDM_SCOPE_PENDING_CONFIRM = "The current specialization has %d Cooldown Manager voice settings waiting to apply.\n\nThe UI will reload once after applying."
zhCN.CDM_SCOPE_PENDING_CONFIRM = "当前专精有 %d 条冷却管理器语音设置等待应用。\n\n应用后将重载一次界面。"
zhTW.CDM_SCOPE_PENDING_CONFIRM = "目前專精有 %d 條冷卻管理器語音設定等待套用。\n\n套用後將重新載入一次介面。"
enUS.CDM_EXTERNAL_CHANGE_PENDING = "Cooldown Manager voices differ from the addon settings. %d changes are waiting to apply."
zhCN.CDM_EXTERNAL_CHANGE_PENDING = "检测到冷却管理器语音与插件保存设置不一致，共有 %d 条更改等待应用。"
zhTW.CDM_EXTERNAL_CHANGE_PENDING = "偵測到冷卻管理器語音與插件儲存設定不一致，共有 %d 條變更等待套用。"
enUS.CDM_APPLY_FAILED = "Failed to apply Cooldown Manager voices."
zhCN.CDM_APPLY_FAILED = "冷却管理器语音应用失败。"
zhTW.CDM_APPLY_FAILED = "冷卻管理器語音套用失敗。"
enUS.CDM_APPLY_VERIFY_FAILED = "Could not verify all Cooldown Manager voice settings after reload."
zhCN.CDM_APPLY_VERIFY_FAILED = "重载后未能确认全部冷却管理器语音设置。"
zhTW.CDM_APPLY_VERIFY_FAILED = "重新載入後未能確認全部冷卻管理器語音設定。"
enUS.CDM_STATUS_APPLIED = "Applied"
zhCN.CDM_STATUS_APPLIED = "已应用"
zhTW.CDM_STATUS_APPLIED = "已套用"
enUS.CDM_STATUS_PENDING = "Waiting to apply"
zhCN.CDM_STATUS_PENDING = "待应用"
zhTW.CDM_STATUS_PENDING = "等待套用"
enUS.CDM_STATUS_APPLY_FAILED = "Apply failed"
zhCN.CDM_STATUS_APPLY_FAILED = "应用失败"
zhTW.CDM_STATUS_APPLY_FAILED = "套用失敗"



enUS.CDM_DELETE_APPLYING = "Deleting the Cooldown Manager voice and reloading the UI."
zhCN.CDM_DELETE_APPLYING = "正在删除冷却管理器语音并重载界面。"
zhTW.CDM_DELETE_APPLYING = "正在刪除冷卻管理器語音並重新載入介面。"
enUS.CDM_APPLY_RESULT_AFTER_RELOAD = "Cooldown Manager voice changes were verified after reload."
zhCN.CDM_APPLY_RESULT_AFTER_RELOAD = "重载后已确认冷却管理器语音更改。"
zhTW.CDM_APPLY_RESULT_AFTER_RELOAD = "重新載入後已確認冷卻管理器語音變更。"
enUS.CDM_STATUS_APPLYING = "Applying…"
zhCN.CDM_STATUS_APPLYING = "正在应用并准备重载"
zhTW.CDM_STATUS_APPLYING = "正在套用並準備重新載入"
enUS.CDM_PRESET_IMPORT_LOCAL_DONE = "Saved %d Cooldown Manager voice presets locally: %d for the current spec, %d for other specs, %d pending, %d invalid."
zhCN.CDM_PRESET_IMPORT_LOCAL_DONE = "已在插件内保存 %d 条冷却管理器语音预设：当前专精 %d 条，其他专精 %d 条，待应用 %d 条，无效 %d 条。"
zhTW.CDM_PRESET_IMPORT_LOCAL_DONE = "已在插件內儲存 %d 條冷卻管理器語音預設：目前專精 %d 條，其他專精 %d 條，等待套用 %d 條，無效 %d 條。"

enUS.LABEL_TEXT_COOLDOWN_COUNTDOWN = "Show cooldown countdown"
zhCN.LABEL_TEXT_COOLDOWN_COUNTDOWN = "显示冷却倒计时"
zhTW.LABEL_TEXT_COOLDOWN_COUNTDOWN = "顯示冷卻倒數"
enUS.LABEL_TALENT_LOAD_FILTER = "Load if learned"
zhCN.LABEL_TALENT_LOAD_FILTER = "检测载入天赋"
zhTW.LABEL_TALENT_LOAD_FILTER = "偵測載入天賦"
enUS.LABEL_CHECK_TALENT = "Talent changes CD"
zhCN.LABEL_CHECK_TALENT = "检测改变CD天赋"
zhTW.LABEL_CHECK_TALENT = "偵測改變CD天賦"



enUS.LABEL_CD_MODE = "CD Type"
zhCN.LABEL_CD_MODE = "CD类型"
zhTW.LABEL_CD_MODE = "CD類型"
enUS.CD_MODE_FIXED = "Fixed CD"
zhCN.CD_MODE_FIXED = "固定CD"
zhTW.CD_MODE_FIXED = "固定CD"
enUS.CD_MODE_READY = "Ready"
zhCN.CD_MODE_READY = "就绪"
zhTW.CD_MODE_READY = "就緒"
enUS.CD_MODE_COOLDOWN = "On Cooldown"
zhCN.CD_MODE_COOLDOWN = "冷却中"
zhTW.CD_MODE_COOLDOWN = "冷卻中"



enUS.LABEL_CDM_PICK = "Quick Skill Select"
zhCN.LABEL_CDM_PICK = "快速选择技能"
zhTW.LABEL_CDM_PICK = "快速選擇技能"
enUS.PLACEHOLDER_CDM_PICK = "Select a skill (out of combat)"
zhCN.PLACEHOLDER_CDM_PICK = "选择技能（非战斗）"
zhTW.PLACEHOLDER_CDM_PICK = "選擇技能（非戰鬥）"
enUS.LABEL_SKILL_FILTER = "Class / Spec"
zhCN.LABEL_SKILL_FILTER = "职业 / 专精"
zhTW.LABEL_SKILL_FILTER = "職業 / 專精"
enUS.PLACEHOLDER_NO_MATCH_SKILL = "No matching skills"
zhCN.PLACEHOLDER_NO_MATCH_SKILL = "无匹配技能"
zhTW.PLACEHOLDER_NO_MATCH_SKILL = "無符合技能"
enUS.CDM_SEARCH_SKILL = "Search skill"
zhCN.CDM_SEARCH_SKILL = "搜索技能"
zhTW.CDM_SEARCH_SKILL = "搜尋技能"
enUS.MSG_NEED_LOAD_TALENT_ID = "Load-talent check is enabled. Please enter a valid Talent ID."
zhCN.MSG_NEED_LOAD_TALENT_ID = "已启用检测载入天赋，请填写有效的天赋ID。"
zhTW.MSG_NEED_LOAD_TALENT_ID = "已啟用偵測載入天賦，請填寫有效的天賦ID。"

enUS.TAB_EVENT_VOICE = "Event Voice"
zhCN.TAB_EVENT_VOICE = "事件语音"
zhTW.TAB_EVENT_VOICE = "事件語音"
enUS.ENTRY_TYPE_EVENT = "Event Voice"
zhCN.ENTRY_TYPE_EVENT = "事件语音"
zhTW.ENTRY_TYPE_EVENT = "事件語音"
enUS.SELECT_ALERT_TYPE_EVENT_DESC = "Play a voice immediately when combat, Mythic+, encounter, or another supported event occurs."
zhCN.SELECT_ALERT_TYPE_EVENT_DESC = "战斗、大秘境、首领战等支持的事件发生时立即播放语音。"
zhTW.SELECT_ALERT_TYPE_EVENT_DESC = "戰鬥、大秘境、首領戰等支援的事件發生時立即播放語音。"
enUS.SECTION_EVENT_VOICE_PARAMS = "Event Settings"
zhCN.SECTION_EVENT_VOICE_PARAMS = "事件参数"
zhTW.SECTION_EVENT_VOICE_PARAMS = "事件參數"
enUS.LABEL_EVENT_VOICE_TYPE = "Event"
zhCN.LABEL_EVENT_VOICE_TYPE = "触发事件"
zhTW.LABEL_EVENT_VOICE_TYPE = "觸發事件"
enUS.PLACEHOLDER_SELECT_EVENT_VOICE = "Select an event"
zhCN.PLACEHOLDER_SELECT_EVENT_VOICE = "选择触发事件"
zhTW.PLACEHOLDER_SELECT_EVENT_VOICE = "選擇觸發事件"
enUS.LABEL_EVENT_THROTTLE = "Duplicate guard (sec)"
zhCN.LABEL_EVENT_THROTTLE = "防重复间隔（秒）"
zhTW.LABEL_EVENT_THROTTLE = "防重複間隔（秒）"
enUS.LABEL_EVENT_LOAD_CONTEXT = "Load in"
zhCN.LABEL_EVENT_LOAD_CONTEXT = "载入场景"
zhTW.LABEL_EVENT_LOAD_CONTEXT = "載入場景"
enUS.EVENT_LOAD_WORLD = "World"
zhCN.EVENT_LOAD_WORLD = "世界"
zhTW.EVENT_LOAD_WORLD = "世界"
enUS.EVENT_LOAD_DELVE = "Delve"
zhCN.EVENT_LOAD_DELVE = "地下堡"
zhTW.EVENT_LOAD_DELVE = "探究"
enUS.EVENT_LOAD_DUNGEON = "Dungeon"
zhCN.EVENT_LOAD_DUNGEON = "五人地下城"
zhTW.EVENT_LOAD_DUNGEON = "五人地下城"
enUS.EVENT_LOAD_RAID = "Raid"
zhCN.EVENT_LOAD_RAID = "团队副本"
zhTW.EVENT_LOAD_RAID = "團隊副本"
enUS.LABEL_EVENT_DUNGEON_SCOPE = "Dungeon selection"
zhCN.LABEL_EVENT_DUNGEON_SCOPE = "五人地下城范围"
zhTW.LABEL_EVENT_DUNGEON_SCOPE = "五人地下城範圍"
enUS.LABEL_EVENT_RAID_SCOPE = "Raid selection"
zhCN.LABEL_EVENT_RAID_SCOPE = "团队副本范围"
zhTW.LABEL_EVENT_RAID_SCOPE = "團隊副本範圍"
enUS.EVENT_LOAD_MODE_ANY = "Any"
zhCN.EVENT_LOAD_MODE_ANY = "任意"
zhTW.EVENT_LOAD_MODE_ANY = "任意"
enUS.EVENT_LOAD_MODE_CURRENT_SEASON = "All current-season"
zhCN.EVENT_LOAD_MODE_CURRENT_SEASON = "当前赛季全部"
zhTW.EVENT_LOAD_MODE_CURRENT_SEASON = "目前賽季全部"
enUS.EVENT_LOAD_MODE_SPECIFIC = "Specific current-season instances"
zhCN.EVENT_LOAD_MODE_SPECIFIC = "指定当前赛季副本"
zhTW.EVENT_LOAD_MODE_SPECIFIC = "指定目前賽季副本"
enUS.LABEL_EVENT_DUNGEON_SPECIFIC = "Specific dungeons"
zhCN.LABEL_EVENT_DUNGEON_SPECIFIC = "指定五人地下城（可多选）"
zhTW.LABEL_EVENT_DUNGEON_SPECIFIC = "指定五人地下城（可多選）"
enUS.LABEL_EVENT_RAID_SPECIFIC = "Specific raids"
zhCN.LABEL_EVENT_RAID_SPECIFIC = "指定团队副本（可多选）"
zhTW.LABEL_EVENT_RAID_SPECIFIC = "指定團隊副本（可多選）"
enUS.PLACEHOLDER_EVENT_DUNGEON_SPECIFIC = "Select current-season dungeons"
zhCN.PLACEHOLDER_EVENT_DUNGEON_SPECIFIC = "选择当前赛季五人本"
zhTW.PLACEHOLDER_EVENT_DUNGEON_SPECIFIC = "選擇目前賽季五人本"
enUS.PLACEHOLDER_EVENT_RAID_SPECIFIC = "Select current-season raids"
zhCN.PLACEHOLDER_EVENT_RAID_SPECIFIC = "选择当前赛季团本"
zhTW.PLACEHOLDER_EVENT_RAID_SPECIFIC = "選擇目前賽季團本"
enUS.MSG_EVENT_DUNGEON_SPECIFIC_REQUIRED = "Select at least one current-season dungeon."
zhCN.MSG_EVENT_DUNGEON_SPECIFIC_REQUIRED = "请至少选择一个当前赛季五人地下城。"
zhTW.MSG_EVENT_DUNGEON_SPECIFIC_REQUIRED = "請至少選擇一個目前賽季五人地下城。"
enUS.MSG_EVENT_RAID_SPECIFIC_REQUIRED = "Select at least one current-season raid."
zhCN.MSG_EVENT_RAID_SPECIFIC_REQUIRED = "请至少选择一个当前赛季团队副本。"
zhTW.MSG_EVENT_RAID_SPECIFIC_REQUIRED = "請至少選擇一個目前賽季團隊副本。"
enUS.EVENT_LOAD_SPECIFIC_COUNT = "%d selected"
zhCN.EVENT_LOAD_SPECIFIC_COUNT = "已选%d个"
zhTW.EVENT_LOAD_SPECIFIC_COUNT = "已選%d個"
enUS.MSG_EVENT_LOAD_CONTEXT_REQUIRED = "Select at least one event load location."
zhCN.MSG_EVENT_LOAD_CONTEXT_REQUIRED = "请至少选择一个事件语音载入场景。"
zhTW.MSG_EVENT_LOAD_CONTEXT_REQUIRED = "請至少選擇一個事件語音載入場景。"
enUS.EVENT_LOAD_ALL = "All locations"
zhCN.EVENT_LOAD_ALL = "全部场景"
zhTW.EVENT_LOAD_ALL = "全部場景"
enUS.SAVED_EVENT_LOAD_CONTEXTS = "Load: %s"
zhCN.SAVED_EVENT_LOAD_CONTEXTS = "载入：%s"
zhTW.SAVED_EVENT_LOAD_CONTEXTS = "載入：%s"
enUS.SAVED_EVENT_THROTTLE = "Duplicate guard: %.1fs"
zhCN.SAVED_EVENT_THROTTLE = "防重复：%.1f秒"
zhTW.SAVED_EVENT_THROTTLE = "防重複：%.1f秒"

enUS.EVENT_VOICE_COMBAT_START = "Combat started"
zhCN.EVENT_VOICE_COMBAT_START = "进入战斗"
zhTW.EVENT_VOICE_COMBAT_START = "進入戰鬥"
enUS.EVENT_VOICE_COMBAT_END = "Combat ended"
zhCN.EVENT_VOICE_COMBAT_END = "脱离战斗"
zhTW.EVENT_VOICE_COMBAT_END = "脫離戰鬥"
enUS.EVENT_VOICE_MYTHIC_PLUS_START = "Mythic+ started"
zhCN.EVENT_VOICE_MYTHIC_PLUS_START = "大秘境开始"
zhTW.EVENT_VOICE_MYTHIC_PLUS_START = "大秘境開始"
enUS.EVENT_VOICE_MYTHIC_PLUS_COMPLETE = "Mythic+ completed"
zhCN.EVENT_VOICE_MYTHIC_PLUS_COMPLETE = "大秘境完成"
zhTW.EVENT_VOICE_MYTHIC_PLUS_COMPLETE = "大秘境完成"
enUS.EVENT_VOICE_ENCOUNTER_START = "Encounter started"
zhCN.EVENT_VOICE_ENCOUNTER_START = "首领战开始"
zhTW.EVENT_VOICE_ENCOUNTER_START = "首領戰開始"
enUS.EVENT_VOICE_ENCOUNTER_SUCCESS = "Encounter defeated"
zhCN.EVENT_VOICE_ENCOUNTER_SUCCESS = "首领击杀"
zhTW.EVENT_VOICE_ENCOUNTER_SUCCESS = "首領擊殺"
enUS.EVENT_VOICE_ENCOUNTER_WIPE = "Encounter wipe"
zhCN.EVENT_VOICE_ENCOUNTER_WIPE = "首领战团灭"
zhTW.EVENT_VOICE_ENCOUNTER_WIPE = "首領戰滅團"
enUS.EVENT_VOICE_READY_CHECK = "Ready check"
zhCN.EVENT_VOICE_READY_CHECK = "就位确认"
zhTW.EVENT_VOICE_READY_CHECK = "就位確認"
enUS.EVENT_VOICE_ROLE_CHECK_START = "Role check started"
zhCN.EVENT_VOICE_ROLE_CHECK_START = "职责确认开始"
zhTW.EVENT_VOICE_ROLE_CHECK_START = "職責確認開始"
enUS.EVENT_VOICE_INCOMING_SUMMON = "Incoming summon"
zhCN.EVENT_VOICE_INCOMING_SUMMON = "收到召唤"
zhTW.EVENT_VOICE_INCOMING_SUMMON = "收到召喚"
enUS.EVENT_VOICE_INCOMING_RESURRECTION = "Incoming resurrection"
zhCN.EVENT_VOICE_INCOMING_RESURRECTION = "收到复活"
zhTW.EVENT_VOICE_INCOMING_RESURRECTION = "收到復活"
enUS.EVENT_VOICE_PLAYER_DEAD = "Player died"
zhCN.EVENT_VOICE_PLAYER_DEAD = "玩家死亡"
zhTW.EVENT_VOICE_PLAYER_DEAD = "玩家死亡"
enUS.EVENT_VOICE_GROUP_MEMBER_DEAD = "Group member died"
zhCN.EVENT_VOICE_GROUP_MEMBER_DEAD = "队友/团员死亡"
zhTW.EVENT_VOICE_GROUP_MEMBER_DEAD = "隊友/團員死亡"

enUS.MSG_INVALID_EVENT_VOICE = "Please select a valid event."
zhCN.MSG_INVALID_EVENT_VOICE = "请选择有效的触发事件。"
zhTW.MSG_INVALID_EVENT_VOICE = "請選擇有效的觸發事件。"
enUS.MSG_DUP_EVENT_VOICE = "An event voice with an overlapping scope already exists."
zhCN.MSG_DUP_EVENT_VOICE = "相同事件语音已存在于重叠的作用域中。"
zhTW.MSG_DUP_EVENT_VOICE = "相同事件語音已存在於重疊的作用域中。"
enUS.MSG_NO_EVENT_SOUND_PATH = "This event alert has no voice file path."
zhCN.MSG_NO_EVENT_SOUND_PATH = "这条事件提醒未填写语音文件路径。"
zhTW.MSG_NO_EVENT_SOUND_PATH = "這條事件提醒未填寫語音檔路徑。"

-- Cast-success and aura alerts share the alert editor; auras only support
-- voice playback.
enUS.OBJECT_TYPE_CAST = "Cast Success"
zhCN.OBJECT_TYPE_CAST = "施法成功"
zhTW.OBJECT_TYPE_CAST = "施法成功"

enUS.OBJECT_TYPE_AURA = "Aura"
zhCN.OBJECT_TYPE_AURA = "光环"
zhTW.OBJECT_TYPE_AURA = "光環"

enUS.ENTRY_TYPE_AURA = "Aura Alert"
zhCN.ENTRY_TYPE_AURA = "光环提醒"
zhTW.ENTRY_TYPE_AURA = "光環提醒"

enUS.TAB_AURA = "Aura Alerts"
zhCN.TAB_AURA = "光环提醒"
zhTW.TAB_AURA = "光環提醒"

enUS.SELECT_ALERT_TYPE_AURA_DESC = "Voice alert when an aura is applied, removed or gains an application (client-side, voice only)."
zhCN.SELECT_ALERT_TYPE_AURA_DESC = "光环出现、消失或叠层增加时的语音提醒（客户端播放，仅支持语音）。"
zhTW.SELECT_ALERT_TYPE_AURA_DESC = "光環出現、消失或疊層增加時的語音提醒（用戶端播放，僅支援語音）。"

enUS.AURA_API_LIMIT_HINT = "Client API limitation: aura alerts only support voice playback. TTS, image and text are not available."
zhCN.AURA_API_LIMIT_HINT = "API 限制：光环提醒目前仅支持语音播放，不支持 TTS、图片和文字。"
zhTW.AURA_API_LIMIT_HINT = "API 限制：光環提醒目前僅支援語音播放，不支援 TTS、圖片和文字。"

enUS.LABEL_AURA_TRIGGER = "Trigger"
zhCN.LABEL_AURA_TRIGGER = "触发"
zhTW.LABEL_AURA_TRIGGER = "觸發"

enUS.LABEL_AURA_UNIT = "Unit"
zhCN.LABEL_AURA_UNIT = "单位"
zhTW.LABEL_AURA_UNIT = "單位"

enUS.AURA_UNIT_PLAYER = "Player"
zhCN.AURA_UNIT_PLAYER = "玩家"
zhTW.AURA_UNIT_PLAYER = "玩家"

enUS.AURA_UNIT_TARGET = "Target"
zhCN.AURA_UNIT_TARGET = "目标"
zhTW.AURA_UNIT_TARGET = "目標"

enUS.AURA_UNIT_FOCUS = "Focus"
zhCN.AURA_UNIT_FOCUS = "焦点"
zhTW.AURA_UNIT_FOCUS = "焦點"

enUS.AURA_TRIGGER_APPLIED = "Applied"
zhCN.AURA_TRIGGER_APPLIED = "出现"
zhTW.AURA_TRIGGER_APPLIED = "出現"

enUS.AURA_TRIGGER_REMOVED = "Removed"
zhCN.AURA_TRIGGER_REMOVED = "消失"
zhTW.AURA_TRIGGER_REMOVED = "消失"

enUS.AURA_TRIGGER_APPLICATIONS = "Applications increased"
zhCN.AURA_TRIGGER_APPLICATIONS = "叠层增加"
zhTW.AURA_TRIGGER_APPLICATIONS = "疊層增加"

enUS.MSG_AURA_VOICE_ONLY = "Aura alerts only support voice playback."
zhCN.MSG_AURA_VOICE_ONLY = "光环提醒仅支持语音播放。"
zhTW.MSG_AURA_VOICE_ONLY = "光環提醒僅支援語音播放。"

enUS.MSG_INVALID_AURA_TRIGGER = "Choose when the aura alert should play."
zhCN.MSG_INVALID_AURA_TRIGGER = "请选择光环提醒的触发时机。"
zhTW.MSG_INVALID_AURA_TRIGGER = "請選擇光環提醒的觸發時機。"

enUS.MSG_AURA_REGISTER_FAILED = "Aura alert registration failed (the client refused it); it will retry after combat or a zone change."
zhCN.MSG_AURA_REGISTER_FAILED = "光环提醒注册失败（客户端拒绝了该注册），将在脱战或切换区域后重试。"
zhTW.MSG_AURA_REGISTER_FAILED = "光環提醒註冊失敗（用戶端拒絕了該註冊），將在脫戰或切換區域後重試。"
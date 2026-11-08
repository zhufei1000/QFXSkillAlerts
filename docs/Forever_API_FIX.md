# 无限版 API 修复

版本保持 1.0.245；本地开发测试，不作为正式发布。

## 代码变化

- `Compat.lua` 优先使用 `C_SpecializationInfo.GetSpecialization` / `GetSpecializationInfo`，集中提供当前作用域、专精列表及天赋配置读取。按目标构建契约，跨职业专精详情仍通过共享的全局 `GetSpecializationInfoForClassID` 查询。
- `Scope.lua`、`CDMVoiceService.lua`、主入口和配置状态使用上述兼容层，实际客户端专精 ID 不再被旧全局函数缺失掩盖。
- `Resolver.lua` 恢复无限版的真实 Trait 判断。当前配置未就绪时，不把未知天赋视为已选择；支持 Camelot 当前双天赋组配置回退。切换天赋的现有事件继续使缓存失效。
- 编辑器恢复天赋加载条件及天赋修改固定 CD 的控件，可查询实际职业专精；保留“全部专精”选项。
- CDM 存储读取合并无限版旧 scope 0 记录与当前实际 ID 的记录，当前 ID 的同名记录优先，禁用状态可以屏蔽继承语音。删除／撤销仍编辑继承记录的原存储位置；原数据无需整批迁移。旧待移除记录保留，当前作用域的显式覆盖不继承过时的移除计划。
- `Runtime.lua` 只在 `SPELL_UPDATE_COOLDOWN` 回调中读取 `isOnGCD`。轮询使用该事件的非 secret 状态快照；新施法和过图会使旧快照失效。处理器忽略事件载荷，不访问或修改暴雪帧、显示缓存或布局。`SPELL_UPDATE_CHARGES` 使用可读取的充能状态。未知 GCD 状态等待可信事件后再建立监视。
- `Bloodlust.lua` 在查询前逐法术检查 `ShouldSpellAuraBeSecret`，保留可公开查询的疲劳光环；不再按实例 ID 请求需要额外访问权限的光环。更新事件重查已知疲劳 ID，并限制为每 0.2 秒至多一次；新增／完整更新仍立即处理。普通瞬时查询失败不会中断事件分发。

## 验证

- 36 个 Lua 回归脚本通过。
- 12 组真实构建器渲染场景通过：enUS / zhCN / zhTW，Retail / Forever，独立 / 管理中心已加载。
- 111 个运行 Lua 文件语法检查通过。
- 新增契约测试覆盖：无旧全局时的 C 命名空间、双天赋组回退、未选／已选／未知天赋、120 秒与 60 秒实际业务构建、scope 0 继承及删除恢复、事件外禁止读取 GCD、新施法使旧快照失效、就绪／冷却开始双边沿、限制查询的事前拦截。
- API 基线为本机无限版 1.60.1.70790，与 1.60.1.70840 的相关文档及实现一致。来源见审查报告。

## 同步与游戏验证

只同步本次修改的运行文件；覆盖前备份，核对源码、整合副本、已安装正式服客户端的 SHA-256。无限服未安装时不自动安装。不修改 WTF 或玩家 SavedVariables 文件，TOC、SavedVariables 声明和版本号保持不变。

新测试包为 `releases/QFXSkillAlerts_1.0.245_forever_api_fixed_test.zip`。请使用新包验证；早期同版测试包保留用于追溯，不代表修复后的代码。

实机仍需验证：

1. 无限版切换两组天赋，检查天赋加载条件及固定 CD 的 120/60 秒切换。
2. 验证已有全部专精提醒、实际职业专精提醒及 CDM 语音的显示、删除、撤销和重载保存。
3. 配置技能“就绪”和“冷却中”语音，连续施放公共 CD 技能；检查无提前、重复或过图误播。
4. 战斗中验证疲劳光环提醒，确认受限光环不报错、公开疲劳光环正常播放。

尚未登录角色进行上述战斗和音频实测。回滚使用同步备份中对应来源的运行文件，不还原玩家存档。

## 第二轮复核修复（2026-11-08）

版本号仍为 1.0.245。复核确认 TOC 门禁正确且已实机加载：`_forever_` 客户端为 1.60.1.70862，存档已写入 `cdmSkillCatalog[3][1485]`（猎人，无限版自有专精 ID）。以下三项为本轮修复。

### P1：天赋组切换未刷新

无限版通过 `C_SpecializationInfo.SetActiveSpecGroup` 切换双天赋，上报 `ACTIVE_TALENT_GROUP_CHANGED`；暴雪自己的冷却管理器也用该事件（`CooldownViewerSettingsDataProvider.lua:26-29`）。插件原先只订阅 `PLAYER_SPECIALIZATION_CHANGED` / `PLAYER_TALENT_UPDATE` / `SPELLS_CHANGED`。

- `EventHub.lua`、`CDMVoicePresetSync.lua`、`CDMNativeAuraSounds.lua` 增订 `ACTIVE_TALENT_GROUP_CHANGED`；同步模块按作用域变更处理（失效冷却缓存、推进作用域、重置提示、重新捕获目录）。
- `Startup.lua` 新增 `OnTalentGroupChanged`，与专精变更同样失效天赋缓存并以 reset 方式刷新；战斗中延迟到 `PLAYER_REGEN_ENABLED`。
- `Resolver.lua` 天赋缓存构建失败时不再标记 `talentCacheValid`，避免把"数据未就绪"缓存成"全部未选中"整局；重试上限为每秒一次，`InvalidateTalentCache` 会清空重试窗口以便事件驱动立即重读。

该事件在正式服 12.1.5.70783 与无限版 1.60.1 的生成文档中均存在，两端订阅都安全。

### P2：未就绪专精被写入全部专精桶

`CDMVoiceService:GetCurrentClassSpec()` 在无限版读不到专精时返回 0，而 0 是每个专精都会继承的"全部专精"桶。两条自动捕获路径会把当前专精的观测数据写进去，污染全职业。

- `CaptureCurrentSpecCatalog` 与 `CDMVoicePresetStore:CaptureCurrentSpecFromLayout` 改为要求正专精 ID，未就绪时跳过且不消耗捕获节流，后续触发会重试。
- `SaveSkillCatalog` / `SanitizeRecord` 仍接受显式 scope 0，既有全部专精记录的读取、继承、删除与导入不变。

### P2：冷却事件上的全量 Prime

`SPELL_UPDATE_COOLDOWN` 原先每次都跑 `PrimeGameCooldowns`，对已武装记录重建 `cd` 表并重跑约 50 字段的 `ApplyAlertFields`，随后 `EvaluateGameCooldowns` 再重复查询同一批法术。

- `PrimeGameCooldowns` 现在同时记录待武装候选 `gameArmCandidates`（仅配置刷新时重建）。
- 新增 `ArmGameCooldownsFromEvent`，事件里只补建缺失的监视，不重建已武装记录；状态采样与快照仍由 `EvaluateGameCooldowns(now, true)` 完成，isOnGCD 依旧只在该事件内读取。
- 过图与 `WipeCooldowns` 同步清空候选表。

### 验证

- 40 个 Lua 回归脚本通过；新增 `tests/test_talent_group_refresh.lua` 覆盖事件路由、战斗延迟 reset、未就绪缓存可重试与重试节流。
- `test_forever_compat.lua` 增加未就绪专精不得创建 scope 0 目录／profiles 桶、显式正专精仍正常写入的断言。
- `test_game_state_event_contract.lua` 增加"冷却事件不得重建已武装记录"的断言。
- 111 个运行 Lua 文件语法检查通过；TOC 审计两个子包各 49／62 个脚本，零缺失零孤儿。

### 同步与备份

本轮只改 `QFXSkillAlerts/Core/` 下 8 个运行文件：`EventHub`、`Startup`、`Resolver`、`CDMVoicePresetSync`、`CDMNativeAuraSounds`、`CDMVoiceService`、`CDMVoicePresetStore`、`Runtime`。配置子包未改动。

同步前核对三处目标彼此一致且均为修改前基线，无独立改动被覆盖。备份位置：`D:/我发布的插件/群飞轩整合包/archive/skillalerts_talent_scope_hotpath_20261108_214934/`，按 `integration` / `client_retail` / `client_forever` 区分来源，共 24 个被替换文件，备份后逐文件校验 SHA-256 一致才覆盖。

同步目标：整合副本 `群飞轩整合包/integrations/QFXSkillAlerts`、客户端 `_retail_/Interface/AddOns/QFXSkillAlerts`、`_forever_/Interface/AddOns/QFXSkillAlerts`。同步后两个子包在源码与三处目标间全量 SHA-256 零差异零缺失。未修改 WTF 与玩家 SavedVariables（无限版存档 mtime 保持 2026-11-08 20:37:32），版本号与 TOC 声明不变。

### 本轮未处理

- 审查基线为 70840，实机为 70862，两者差异尚未核对。
- `Bloodlust` 的 0.2 秒节流是丢弃而非延迟；`ShouldSpellAuraBeSecret` 未包 pcall。
- `MainFrameBuilder.lua:46` 版本号硬编码为 `"--"`。
- 共享 `QFXWidgets.lua` 的 `F:Cog` 仍只用 `GetMouseFocus`（本插件未使用 Cog 与 keybind，无影响），需在上游修复。
- 实机仍需验证：切换两组天赋后 120/60 秒固定 CD 与天赋加载条件是否跟随；登录瞬间专精未就绪时不再产生 scope 0 目录；密集战斗下就绪语音不提前且开销下降。

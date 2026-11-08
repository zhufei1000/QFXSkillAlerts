# 无限版 API 审查

审查日期：2026-11-07。对象：QFXSkillAlerts / QFXSkillAlerts_Config 1.0.245 当前工作副本。

本文记录修复前的审查结果。后续已针对这些问题修复运行代码；当前修复与验证状态见 [FOREVER_API_FIX.md](FOREVER_API_FIX.md)。

## 客户端与证据基线

- 本机 `D:/World of Warcraft/.build.info`：无限版 `wowf` 为 `1.60.1.70790`。
- 匹配的暴雪 UI 提取源码：[eac30af / 1.60.1.70790](https://github.com/Gethe/wow-ui-source/tree/eac30af597e5aaa43a60f6675ef5fdcea100375f)。
- 最新分支：[5987a8e / 1.60.1.70840](https://github.com/Gethe/wow-ui-source/tree/5987a8e2304c1331346dc861d5ccacf4c510cf0f)。
- 两提交之间只有 5 个文件变化，涉及登录角色选择、社交通知、订阅界面及版本文件。生成 API 文档、CooldownViewer、PlayerSpells 和 DeprecatedSpecialization 均无变化。
- 本地参考源码：`archive/forever-api-source/`。模拟复现脚本：`archive/forever-api-audit/reproduce.lua`。

## 发现

### P1：把无限版天赋一律判为已选中

位置：`QFXSkillAlerts/Core/Resolver.lua:468`、`QFXSkillAlerts/Core/Compat.lua:56`、`QFXSkillAlerts_Config/UI/EditorFields.lua:2253`。

`Resolver:IsTalentSelectedCached()` 在识别到 Forever 后直接返回 `true`，绕过实际天赋缓存；编辑器同时隐藏天赋修改 CD 和天赋加载条件。

无限版的天赋外观与正式服不同，但仍通过 `C_Traits` 管理。Camelot 专用界面直接调用 `C_Traits.GetGroupDisplayInfoByTreeID`、`GetGroupCurrencyInfo`，并通过 `C_SpecializationInfo.GetCombatConfigIDForSpecGroup` 读取双天赋配置。共用基类还读取 `C_ClassTalents.GetActiveConfigID`。不能根据“不是正式服专精界面”推导“没有 Trait 配置”。

使用真实 Resolver 与 RuntimeConfigBuilder 的模拟结果：缓存成功读取选中的天赋 12345；未选中的 54321 仍返回 `true`。一条基础 CD 为 120 秒、天赋 CD 为 60 秒且要求选择 54321 才加载的记录，被错误加载并采用 60 秒。

修正方向：保留适合无限版的职业／全部专精 UI，按能力读取真实 Trait 配置；必要时增加当前天赋组配置的回退。数据未就绪与明确未选择要分别处理，不能把任意天赋都当成已选择。

证据：[Camelot 天赋界面](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua#L95)、[共用配置读取](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentsFrame.lua#L883)。

### P1：在非事件轮询中依赖 isOnGCD 判断就绪

位置：`QFXSkillAlerts/Core/Runtime.lua:232`、`:260`、`:429`。

`SpellCooldownInfo.isOnGCD` 确实存在并标为 `NeverSecret`，但同一字段的文档明确限制了可信使用时机：响应 `SPELL_UPDATE_COOLDOWN` 时。当前 Runtime 有意不订阅该事件，在 OnUpdate 轮询中直接使用该字段，连续两次为 true 就可能把仍为 `isActive=true` 的技能视为就绪。

两次采样不会补足 API 没有承诺的字段有效性。模拟提供非事件时刻允许出现的不可靠 GCD 标记，真实 Runtime 会播放一次 Ready。此结果说明契约缺口；尚未测量实际客户端发生频率。

修正方向：按对应构建的事件契约建立冷却状态采样／缓存边界，或采用其他文档保证可靠的状态路径；不要用额外轮询次数作为正确性保证。

证据：[SpellCooldownInfo 字段契约](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua#L30)。

### P2：当前作用域读取未接入 C_SpecializationInfo

位置：`QFXSkillAlerts/Core/Compat.lua:75`、`QFXSkillAlerts/Core/Scope.lua:24`、`QFXSkillAlerts/Core/CDMVoiceService.lua:219`。

三处仍读取全局 `GetSpecialization` / `GetSpecializationInfo`。暴雪提供这些旧别名的 `Blizzard_DeprecatedSpecialization` 明确只允许 `classic, standard`，不包含 Camelot；无限版自己的 CooldownViewer 则直接使用 `C_SpecializationInfo`。

在 C 命名空间有有效结果、旧全局不存在的场景中，当前实现直接返回 0。0 可以继续作为本插件“全部专精”的存储哨兵；问题是当前代码没有区分“主动采用统一作用域”与“未读取到现存 API”。因此，依赖正 ID 的已保存记录／导入记录不能以当前实现验证为已适配。

模拟结果：命名空间返回 1489，而 Scope 和 Compat 均返回 0。此数字来自 Camelot 暴雪界面的萨满配置标识；模拟不代表读取了本机角色。

修正方向：集中通过 Compat 优先读取 C 命名空间，明确把真实客户端 ID 映射到本插件作用域的规则；不要在多个模块内分别回落为 0。修改时保留既有 `[classID][0]` 记录的加载兼容。

证据：[旧别名包的游戏类型限制](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_DeprecatedSpecialization/Blizzard_DeprecatedSpecialization.toc#L3)、[无限版 CooldownViewer 的实际调用](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerUtil.lua#L27)。

### 条件性风险：嗜血光环查询缺少调用前的限制判断

位置：`QFXSkillAlerts/Core/Bloodlust.lua:155`。

`GetPlayerAuraBySpellID` 标有 `RequiresNonSecretAura`。当前仅在调用返回后检查 secret 值；如果调用本身被限制，错误会从 `CheckExhaustionFresh` 传播出去。外层 pcall 只包围前面的更新过滤函数，没有覆盖该查询。

模拟 API 拒绝查询时已复现错误传播。但还没有证明当前疲劳／筋疲力尽 ID 列表中的某个法术在实际无限版场景会被归类为 secret，所以这项是需实机确认的风险，不能写成“进战斗必报错”。

核验／修正方向：按法术检查 `C_Secrets.ShouldSpellAuraBeSecret` 及目标构建的访问契约；不要仅依据 `ShouldAurasBeSecret` 把所有疲劳光环一概禁用，也不要把 pcall 当作判断权限的方法。

证据：[光环查询限制](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua#L397)。

## 已核对的正确部分

- 业务模块静态扫描到的 40 个显式 `C_命名空间.函数` 引用均能在本构建的生成文档中找到。此计数不包含第三方库、工厂和通过局部别名动态调用的额外符号，不等同于所有调用语义都正确。
- `GetBuildInfo` 第四返回值用于读取 Interface 的位置正确；Forever 的接口识别没有因项目 ID 仍为 Mainline 而误判。
- 冷却管理器分类、条目和有效事件查询的函数名、参数位置正确；调用的布局管理器方法仍存在。
- `CooldownViewerAlert_PlayAlert(cooldownItem, spellName, alert, soundSubType)` 的前三个 hook 参数对应正确。
- `AddAuraSound(trigger, soundInfo)` / `RemoveAuraSound(id)` 参数结构、Added=0 / ApplicationsIncreased=1 / Removed=2 对应正确。该 API 最长播放 5 秒，长音频可能截断，这是客户端契约限制。
- TTS 的语音 ID 查询及 `SpeakText(voiceID, text, rate, volume, overlap)` 参数顺序正确。
- `GetSpellCooldown` / `GetSpellCharges` 的调用方式及 NeverSecret 状态字段选择正确，`isOnGCD` 的可信时机另见上面的 P1。
- UNIT_SPELLCAST_SUCCEEDED 前三个参数的解包位置正确；新增的第四个 castBarID 不会使当前前三项错位。

## 验证结果与边界

- 原有 34 个回归脚本全部通过。
- 审查复现脚本的 4 个契约模拟场景均重现上述行为。
- 现有 `test_forever_compat.lua` 明确要求任意天赋被视为满足，渲染测试要求隐藏天赋控件；这些断言验证了现有实现，没有验证这些前提是否符合无限版 API。修复时需要同步修正测试预期。
- 尚未登录角色进行战斗、双天赋切换、受限光环和声音播放实测。
- 审查当时没有修改玩家存档、版本号和运行文件。早期 `forever_factory_test.zip` 包含本报告列出的问题，后续测试应使用 `forever_api_fixed_test.zip`。

历史复现命令（只适用于修复前的源码；修复后由 `tests/test_forever_api_contracts.lua`、`tests/test_game_state_event_contract.lua` 和 `tests/test_bloodlust_secret.lua` 验证相应行为）：

```powershell
lua archive/forever-api-audit/reproduce.lua
```

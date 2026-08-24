# Changelog

## 1.0.219 - 2026-08-24

- Added Cooldown Manager presets to the saved-entry list with ordering and collection membership support; deleting a collection now deletes its contained CDM presets, and stale collection references are cleaned automatically.
- Kept saved-list work out of combat-sensitive runtime paths and reduced configuration-screen cost with cached snapshots, layout reuse, and deferred export serialization.
- Added an optional fixed-cooldown text countdown using the shared runtime update loop, including compact minute-and-second formatting such as `1m5s`.
- Split the fixed-cooldown load-talent filter from the talent-based cooldown override, with separate talent ID/name controls and migration of existing settings.
- Fixed Bloodlust built-in, shared, and custom voice selection/playback; exposed the global Bloodlust configuration as a single saved entry with single-entry import/export support.
- Extended full and single-entry import/export paths for the new countdown, talent, collection, CDM, and Bloodlust fields while preserving replacement semantics and stale-reference cleanup.
- Removed redundant configuration code, strengthened the dead-code scan, and added regression coverage for the new saved-entry, import/export, countdown, talent, Bloodlust, and performance-sensitive behavior.

## 1.0.207 - 2026-08-03

- Added early channel-gating in the cooldown tick loop so disabled voice or visual channels skip their entire evaluation branch per tick, reducing per-frame work for cooldowns that only use one alert type.
- Added a fast path for single-charge cooldown charge regeneration that replaces the general-purpose while loop with a single conditional check.
- Reused pre-normalized cooldown condition operators and thresholds in the tick hot path instead of normalizing them again for every active alert channel.
- Stopped reevaluating finite-duration visual channels after every enabled channel has already fired for the current cooldown cycle.
- Fixed live config refreshes leaving an untimed image or text alert visible after its active visual channel was disabled.
- Added regression coverage for disabled active-visual cleanup, finite-channel early-return cleanup, and single-charge regeneration.

## 1.0.206 - 2026-07-21

- Reduced combat-time `UNIT_AURA` work by using incremental aura updates to skip all exhaustion lookups for unrelated player aura changes, with a safe full-scan fallback when update data is unavailable or unreadable.
- Reused one Cooldown Manager catalog across every record in a pending-plan or post-reload verification pass, avoiding repeated provider enumeration and spell/icon resolution per saved voice record.
- Cached the active cooldown runtime update interval for each processing period instead of querying combat/update state on multiple rendered frames near the threshold.
- Removed a production-only CDM registry self-check whose result was never consumed.
- Removed 59 Lua files (about 794 KiB) that were not referenced by either addon's TOC: duplicated configuration sources under the runtime addon plus an unused configuration localization copy.
- Added regression coverage for CDM catalog reuse, incremental exhaustion filtering, and cooldown update-interval caching.

## 1.0.205 - 2026-07-21

- Removed the selectable "No custom voice selected" row from the Cooldown Manager voice dropdown while retaining it as placeholder text for genuinely unconfigured rows.
- Empty voice rows are no longer collected as dirty drafts, preventing one incomplete row from blocking Apply All and Reload.
- Added per-dropdown popup strata support and placed searchable CDM voice lists below WoW's IME candidate layer while keeping them above the CDM editor.

## 1.0.204 - 2026-07-21

- Fixed the pending Cooldown Manager voice Apply/Reload prompt being lost when specialization changes were immediately followed by talent, spell, or CDM data refresh events.
- Coalesced event evaluations now retain prompt intent for the complete event burst and retry after Cooldown Manager data becomes available.
- Deferred specialization prompts now retry after combat through `PLAYER_REGEN_ENABLED`.
- Switching away and back resets the target specialization's prompt guard so unresolved entries can prompt again, without repeating the popup on every world/instance transition.

## 1.0.203 - 2026-07-21

- Removed the UI reload from confirmed manual Cooldown Manager voice deletion.
- Manual deletion now runs a dedicated removal-only transaction: remove all matching same-event Sound alerts from equivalent cooldown IDs, verify zero remain, save the Blizzard layout once, and return without locking notifications or reloading.
- Clears the temporary removal tombstone immediately after successful synchronous verification and preserves rollback on any removal or save failure.
- Routes removal-only Apply All batches through the same no-reload transaction, including pending removals created by earlier versions.
- Kept reload behavior unchanged for Apply/Apply All flows that add or replace sounds.

## 1.0.202 - 2026-07-21

- Changed confirmed manual Cooldown Manager voice deletion to immediately remove the matching same-event Sound alerts, save the Blizzard layout once, and reload the UI once instead of requiring a second Apply All action.
- Kept the payload-free removal tombstone only as an internal post-reload verification marker; it is no longer a user-facing pending step for manual deletion.
- Added atomic local-record rollback when immediate deletion cannot build or apply a valid CDM removal plan.
- Preserved the explicitly named local-only deletion API for import and automation callers that intentionally batch later changes.
- Updated deletion confirmation text to state that the Cooldown Manager layout is changed immediately and the UI reloads once.

## 1.0.201 - 2026-07-21

- Fixed old Cooldown Manager sounds continuing to play after replacing an already-applied QFX voice.
- Explicit apply now finds every current-specialization cooldown entry for the same logical spell and removes all same-event Sound alerts from every equivalent cooldown ID.
- Writes exactly one target Sound on the current primary cooldown ID after the complete removal phase, while preserving other spells, other events, and Visual alerts.
- Read-only status evaluation and post-reload verification now check every equivalent cooldown ID so leftover sounds remain pending or report apply failure instead of incorrectly showing Applied.
- Preserved local-only Save/import behavior and the explicit two-phase apply workflow with at most one `SaveLayouts` call and one immediate reload per changed batch.
- Preserved the secret-value safety policy: no `UnlockNotifications`, `UpdateAlert`, or addon-driven Blizzard Cooldown Viewer refresh calls were introduced.

## 1.0.200 - 2026-07-21

- Split Cooldown Manager voice handling into read-only evaluation and explicit apply transactions: local Save, import, login, specialization changes, CDM data events, and external layout saves no longer write Blizzard CDM data or reload the UI.
- Restored per-row Apply as an atomic save-current-draft-and-apply action, and made Apply All and Reload validate and save every dirty editor row before applying all valid pending records for the current specialization.
- Added persistent pending-removal tombstones; applying removals deletes only the saved target payload and preserves other payloads, events, and visual alerts.
- Reworked explicit application into a fully prevalidated two-phase RemoveAlert/AddAlert transaction with one notification lock, one `SaveLayouts` call per changed batch, no `UnlockNotifications`, and one immediate reload to avoid `hasTotem` secret-value taint.
- Added post-reload verification and one-time failure reporting without automatic retry or reload loops, including deferred verification while Cooldown Manager data is not yet readable.
- Updated pending/applied/failed status UI, import and pending prompts, public APIs, and enUS/zhCN/zhTW text while preserving existing test, export/import, and non-CDM features.

## 1.0.199 - 2026-07-21

- Removed every addon-driven Blizzard Cooldown Viewer refresh/notification path and kept the legacy runtime-refresh API as a no-op to prevent secret-value taint such as `hasTotem` failures.
- Replaced `UpdateAlert` voice replacement with validated per-event `RemoveAlert` + `AddAlert` reconciliation for added, unchanged, replaced, and deduplicated outcomes.
- Added pre-delete target validation, exact old-sound snapshots, post-mutation verification, and in-memory rollback before saving when removal, addition, or verification fails.
- Kept each current-specialization batch inside one internal mutation transaction with notification locking, at most one `SaveLayouts` call, one post-save verification pass, and one QFX UI refresh.
- Added coalesced login/world-entry/CDM-data/specialization synchronization with schedule and scope serials so stale specialization tasks cannot write into the new scope.
- Kept imported records for every class and specialization in the local preset store and automatically applies the matching scope when that character logs in or changes specialization.
- Preserved external `SaveLayouts` recovery and permanent saved-list deletion without recursive synchronization, reload prompts, or Viewer frame refreshes.
- Updated runtime statuses, summaries, public API compatibility, and enUS/zhCN/zhTW text while preserving single-entry, all-preset, and full-configuration exports.

## 1.0.198 - 2026-07-21

- Made the effective local Cooldown Manager voice list the single source of truth for every preset source.
- Replaced staged Apply/Reload workflows with immediate save-and-sync plus a manual current-specialization sync action.
- Added exact same-event Sound reconciliation: add missing alerts, update other sounds in place, and remove duplicates without touching visual or other-event alerts.
- Batched reconciliation into one mutation transaction, one `SaveLayouts` call, one runtime refresh, and one verification pass.
- Cleared legacy `pendingApply` data and made login, world entry, CDM data, specialization, combat, media registration, import, and external layout saves retry synchronization automatically.
- Made saved-list deletion remove every exact local target duplicate permanently without reload, while preserving unrelated alerts.
- Updated the editor and enUS/zhCN/zhTW text, preserved single/full preset export, and removed the obsolete apply dialog from the load list.

## 1.0.197 - 2026-07-21

- Split Cooldown Manager voice editing into local Save and confirmed Apply workflows.
- Added local `pendingApply` staging that automatic synchronization and layout capture cannot apply or overwrite.
- Added per-row Save controls, single-entry apply/reload confirmation, and Apply All and Reload for the current specialization.
- Added explicit same-event sound replacement for user-confirmed staged batches while preserving existing sounds during automatic sync.
- Made staged batch application save the Cooldown Manager layout once, mark only verified records as applied, and suppress reload on partial failure.
- Removed reload-required handling from Cooldown Manager voice deletion and removed unsupported-event warning text/tooltips from the editor.
- Removed local staging state from all Cooldown Manager preset exports.

## 1.0.196 - 2026-07-21

- Rebuilt Cooldown Manager saved-list rows from effective local presets with live loaded, pending, missing, conflicting, unsupported, and ambiguous states.
- Added stable preset keys, loaded/unloaded section routing, accessible status text, and green/yellow/orange/gray/red indicators.
- Added external Cooldown Manager layout-save detection so deleted runtime voices are restored while their local presets remain enabled.
- Made preset deletion transactional, exact-target-only, conflict-safe, and rollback-capable.
- Added single-preset export and preset-key editing support, including safe handling when an ability is not currently loaded.

## 1.0.195 - 2026-07-21

- Added searchable SharedMedia voice dropdowns for cooldown, cast-success, and Cooldown Manager voice editing.
- Replaced the dropdown popup scrollbar with a dedicated draggable slider and protected scrollbar interaction from row selection and auto-close behavior.
- Added cross-character Cooldown Manager voice presets with stable event keys and voice identity/path/name matching.
- Added event-driven current-spec synchronization that preserves every existing sound alert and batches layout saving and runtime refresh.
- Added Cooldown Manager preset export/import, full-export integration, manual synchronization, and preset-aware deletion.
- Added safe runtime refresh attempts with a single reload-required fallback state.

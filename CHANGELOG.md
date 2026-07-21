# Changelog

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

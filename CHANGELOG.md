# Changelog

## 1.0.236 - 2026-10-04

- Performance pass: cooldown completion now polls every 0.05s during the final second (alerts land within ~50ms instead of ~100ms) while idle polling is unchanged; the cross-spec skill catalog no longer re-walks every Cooldown Manager category after each fight (5-minute throttle per spec, forced refresh on login / spec change / data load); the catalog no longer builds or stores a long signature string per spec; per-cooldown info no longer retains Blizzard's full raw table; bag rescans use the lightweight item-ID getter instead of allocating an info table per slot.
- The shared dropdown popup now unhooks its per-frame hover / auto-close poll when hidden, so no per-frame work remains after the config UI closes.

## 1.0.235 - 2026-10-04

- Image alerts gained a display-layer setting (frame strata): Background / Low / Medium / High / Dialog / Fullscreen / Fullscreen Dialog (default) / Tooltip, so artwork can sit under or above other UI. The layer applies to the shared image + text frame.
- Image and text alerts can now end early on player events instead of only running their duration out: player dies, player alive (accept rez), player alive (corpse run), enter combat, leave combat, change target, change focus, start moving, stop moving, entering world, change zone, change specialization, mount changed, encounter start, encounter end and level up. Each channel has its own end-event multi-select; when image and text are shown together only the matching part is hidden, and the whole alert is released once both parts are gone. One shared low-frequency event watcher handles all events.
- The editor Test button, the live editor refresh, Bloodlust config and export / import all carry the new fields; Bloodlust entries get the same controls in their Image / Text tabs.
- Regression coverage: `tests/test_visual_end_events.lua` plus extended visual config assertions in `tests/test_event_voice.lua`.

## 1.0.234 - 2026-10-04

- Free-form artwork (custom image paths and SharedMedia images) is no longer cropped: alerts and the editor position preview now draw those textures over the full 0..1 texture coordinates, while spell / item / icon art keeps the 8% per-side crop that hides Blizzard's icon border. This fixes shared images looking cut off.
- The editor position preview resolves SharedMedia images now (it previously fell back to the question-mark icon), and the image-size slider pushes the new size to an already-visible runtime alert immediately, so resizing can be judged live. The editor Test button also passes the SharedMedia image name through, so the test alert previews the shared image correctly.

## 1.0.233 - 2026-10-04

- The shared-image picker now lists every LibSharedMedia media type that carries display textures - `texture` plus `background`, `statusbar` and `border` - instead of only the non-standard `texture` type, and resolves a picked name across those types in the same order. Media packs that register their artwork as background (for example the `QFX_SharedMedia` PersonalTags images) are now selectable; duplicate names collapse to one entry and prefer the `texture` library. The dropdown is searchable like the SharedMedia voice list, and the name lookup is shared with runtime playback, so editor previews and live alerts resolve the same path.
- Regression coverage: `tests/test_shared_media_images.lua` (merged listing, de-duplication, cross-type fetch order).

## 1.0.232 - 2026-10-04

- Event settings page: the "Alert Actions" voice / image / text multi-select now behaves like the cooldown alerts' action selector instead of the locked aura row - the dropdown is interactive, the "Execute" label stays enabled, and the execute row is force-restored when the Settings tab is reopened.
- Image size slider range raised from 16-256 to 16-512; new alerts still default to 96.

## 1.0.231 - 2026-10-04

- Event alerts now support the image and text channels in addition to voice: the editor shows the Image / Text tabs for event entries, a visual-only event (voice unchecked) still fires, and the runtime passes the saved visual configuration straight to the shared notifier, so position, size, duration and the chosen image all apply.
- The image source dropdown gained a "Shared media image" option backed by LibSharedMedia's texture library: any registered SharedMedia texture can be used, the shared image name is saved with the entry, travels through export/import, and is resolved through LSM at playback time. `MediaCatalog` exposes `GetSharedMediaTextureList` / `FetchSharedMediaTexturePath` for this.
- Saving an event entry keeps its image/text flags instead of clearing them, and the "event voice is required" save gate is gone (an event needs at least one channel enabled). Import sanitization no longer strips image/text from event entries.
- Fixed the quick skill picker caching duplicate catalog entries when one spell is exposed by both aura-tracking categories; the cached per-spec catalog is now deduplicated. Updated `tests/test_cdm_picker_categories.lua`, `tests/test_event_voice.lua` (visual-only event coverage) and the event import expectations.
- Event editor fixes: the aura trigger / unit dropdowns no longer leak into the event settings page (the event branch now hides them explicitly), the event settings page shows its own "Alert Actions" section with the voice / image / text multi-select just like cooldown alerts, and the event refresh no longer resets the image / text flags, so the checkboxes and the action dropdown stay in sync and can be toggled.

## 1.0.230 - 2026-10-03

- Cooldown Manager voices for the ready, on-cooldown, aura-applied and aura-removed events are now played by the addon itself instead of through the Cooldown Manager layout. Ready / on-cooldown voices are watched through the NeverSecret cooldown booleans (`isActive` / `isOnGCD` / `isEnabled`) in the addon's own update loop; aura voices are registered with the client through `C_UnitAuras.AddAuraSound` (12.1+), which does the edge detection and playback. Saving or deleting these records no longer writes the Cooldown Manager layout and no longer reloads the UI: they take effect immediately, work in restricted combat, and cannot misfire when the Cooldown Manager rebuilds its item frames (for example when leaving an instance).
- Charge-gained and pandemic-time voices stay on the Cooldown Manager path because the underlying data (`currentCharges`, aura remaining time) is secret while cooldowns are restricted; only those records still apply with a reload.
- Stale Cooldown Manager alerts left in the layout by earlier versions stay silent for the native events, so a voice is never played twice. Charge and pandemic alerts keep playing through the existing hook.
- The Cooldown Manager voice hook now suppresses repeated alerts inside a 0.25s window (configurable through `QFXSkillAlertsDB.cdmVoiceUI.duplicateWindow`), reports playback failures once per payload including the file path, and wraps the handler so hook errors cannot surface as Lua errors.
- New regression coverage: `tests/test_cdm_native_events.lua` (event classification, ready/cooldown edge watching with GCD filtering, aura registration / teardown / restricted retry) and an updated `tests/test_cdm_voice_hook.lua`.
- Code cleanup after the migration: removed the now-unused settings data provider access, two unused registration-state helpers, the duplicated native-event lookup (now shared in `CDMNativeEvents`) and an unused hook argument; the ready/cooldown watcher reuses a single frame and only carries its OnUpdate script while records exist.
- Cooldown Manager ready / on-cooldown voices are now stored as regular cooldown alert entries (`cdMode = "ready"` / `"cooldown"`): the Cooldown Manager voice editor and the cooldown alert editor share one record, the state shown in both editors matches, and the main runtime plays them with the full cooldown alert feature set (conditions, TTS, icons, text). The cooldown alert duplicate check now keeps ready and cooldown entries of the same spell separate. Existing ready / cooldown records are migrated automatically on the next login; aura, charge and pandemic events keep their own paths. The addon-side ready/cooldown watcher is removed.
- The alert editor now covers every alert kind in one place: the type dropdown offers Spell / Item / Cast Success / Aura (with an applied / removed / applications trigger) and the separate Cast Success entry button is gone. Aura alerts are registered through `C_UnitAuras.AddAuraSound` from their saved entries and only support voice playback - the image / text tabs and controls stay disabled for them and saving drops any image/text flags. Existing aura records in `cdmVoiceProfiles` migrate into aura entries together with the ready / cooldown records. The old "CD Alert" label is now "Alerts" / "提醒".

## 1.0.229 - 2026-09-26

- Cooldown Manager voice deletion now reloads the UI after the layout is saved, exactly like the set/apply path. Writing the Cooldown Manager layout from addon code taints it for the rest of the session, and Blizzard's CooldownViewer then errors while refreshing secret aura/totem data in combat (`GetUnitAuras(): Auras cannot be accessed when secret while tainted by 'QFXSkillAlerts'`, `attempt to compare a secret number value`, `hasTotem`). Reloading immediately drops the tainted layout before combat; a deletion that already touched the layout and then failed also reloads. The removal path is renamed `ApplyCDMRemovalPlanAndReload` to match the behavior, and the delete confirmation now shows the applying/reloading status on success.
- Cooldown Manager writes are now blocked while secret values are active (`C_Secrets.ShouldCooldownsBeSecret`, e.g. raids and Mythic+), not just during combat, so restricted content can no longer taint the layout. The blocked message now covers combat and restricted content in all three locales.
- Bloodlust / Exhaustion detection guards every aura read with `issecretvalue`: secret player auras, secret `addedAuras` / `updatedAuraInstanceIDs` payloads, and secret `spellId` / `expirationTime` fields are skipped instead of compared or converted, so the addon no longer errors or touches restricted aura data in combat. Behavior outside restricted content is unchanged.
- New regression coverage: `tests/test_bloodlust_secret.lua` plus restricted-state and removal-reload cases in `tests/test_cdm_explicit_apply.lua`.

## 1.0.228 - 2026-09-19

- Fixed the encounter-success and encounter-wipe event voices erroring on every boss kill or wipe since patch 12.0.7: `ENCOUNTER_END` gained a sixth `encounterUnitStatus` table argument, and the shared matcher passed the whole `select(5, ...)` tail into `tonumber()`, which then received the table as its number-base argument. The success flag is now read as a single value, so both the legacy five-argument and the current six-argument event payloads match correctly. Regression coverage in `tests/test_event_voice.lua`.

## 1.0.227 - 2026-09-13

- Cross-spec skill picking now uses persistent per-spec catalogs stored in saved variables (`cdmSkillCatalog`): each specialization's Cooldown Manager skill list is captured automatically when that spec is loaded in game (login, specialization change, zone entry, Cooldown Manager data load, combat end) and when either editor is opened. Capture prefers the client's full category set when available, so it includes not-yet-learned abilities. The picker lists every cached catalog plus saved/imported presets under "Class·Spec · Skill", with no cross-spec dedup (the same spell is listed once per spec); the current spec's live layout wins and only missing catalog entries are appended. The class/spec selector in front of the picker is a single-select that defaults to the current spec, marks cached specs with a green check, and the editor hint states the cross-spec limitation (a spec must be logged in once before its full list is available).
- The skill picker in the cooldown/cast editor is now labeled "Quick Skill Select" (it only fills the spell ID and name) and gains a class/spec multi-select filter in front of it, so saved Cooldown Manager presets from other specs can be filtered and picked directly; "All Specs" is the default and the picker updates live without closing the filter popup.
- Code cleanup: removed dead UI paths and legacy leftovers — the unused scope popup code, the custom-scope dropdown item caches, the hidden spell/item checkbox, an unused dialog text helper wrapper, dead table helpers, the orphaned legacy database migration module, and 75 unused localization keys. No behavior change.
- UI architecture audit follow-up: bounded the saved-list row cache (it multiplied entries by viewer class/spec/race and could grow across long sessions) and cached the Cooldown Manager picker catalog per CDM data serial / current spec / combat state instead of rebuilding it on every editor push.
- New alerts now default to the SharedMedia sound source instead of the built-in sound list; pick a shared sound in the sound section. Existing saved entries keep their stored source.
- Added an `On Cooldown` CD type: it announces when the game reports the real cooldown starting (after the cast GCD clears), using the same NeverSecret state watch as `Ready`. It is cast-driven only — a config refresh while the cooldown is already running never announces, and GCD-only casts stay silent. Fixed CD number, early-warning conditions and the CD-change talent stay disabled like `Ready`; the mode survives save/load/export/import and is shown in the saved list.
- The "Pick from Cooldown Manager" skill picker no longer lists the aura-tracking categories (Tracked Buffs / Tracked Bars): CD alerts only detect real spell cooldowns and readiness edges, so aura trackers are excluded here and belong in the Cooldown Manager voice editor instead.
- Fixed the spell/item Type dropdown staying hidden after an event-voice entry had been opened in the same editor session; returning to a cooldown or cast entry now re-shows it.
- Performance audit follow-up: talent-unloaded entries now stay completely idle. The runtime config builder evaluates the talent load filter before registering bag/equipment refresh needs or resolving item triggers, and the bag-state signature skips talent-blocked entries; they only wake on a talent or scope refresh. Verified the shared OnUpdate loop only runs while a cooldown timer or a `Ready` watch is armed, and the readiness watch exists only for the duration of a watched cast (no always-on tickers or periodic rebuilds).
- Refreshed the "CD alert" hint in the new-alert chooser so it describes the current feature set: fixed-CD or ready alerts for spells and items with voice / icon / text, early warning, and talent / equipment filters.
- Cooldown alerts: the "CD Changes To" talent only affects the fixed timer, so its controls are now disabled while the CD type is `Ready` and the data is dropped on save and export/import for readiness-edge entries; the independent "load only if learned" talent filter keeps working for every CD type.
- Cooldown Manager voice editor: the event dropdown now marks events that already have a voice with a green check, and the section hint explains that one ability can map several events (Ready / On Cooldown / Charge Gained …) to separate voices. Playback follows Blizzard's alert trigger and may lag slightly behind it.
- Saved cooldown entries now show their CD type in the list ("CD Type: Fixed" / "CD Type: Ready"), translated from the stored mode with the legacy `gameStateCD` flag and the removed `charge` mode normalized to Ready. Items, casts and empty slots keep the old row text.
- Replaced the editor's "Select Scope" popup with always-visible multi-select dropdowns: a compact two-row layout with inline labels, races on the first row and the class multi-select paired with a linked spec multi-select on the second. Class and spec names are shown in their class color, selections are visible without opening the popup, and class toggles prune stale spec selections while keeping the popup open. The "All Races / Classes / Specs" entries are exclusive (selecting one clears concrete choices and picking any concrete entry clears "All"), and long selections collapse to a localized count summary instead of a truncated list.
- Replaced the spell/item checkbox with a Type dropdown in front of the Cooldown Manager picker; the picker is now half width. Item entries keep the original ID / name / fixed-CD layout and load checkboxes. New cooldown entries now default to the `Ready` CD type (game readiness edge, no manual cooldown number); existing saved entries keep their stored mode, and item/cast entries still force `Fixed CD`.
- Rearranged the spell section of the alert editor: the Cooldown Manager skill picker now sits on the first row, the fixed-CD field is replaced by a "CD Type" dropdown (Fixed CD / Ready) with the fixed-CD seconds input beside it, and the CD-change talent and load-talent groups each get their own row. Item entries keep the original ID / name / fixed-CD layout and their load checkboxes. `Ready` mode uses the spell-cooldown readiness edge (first charge available for charge spells); per-charge announcements use the Cooldown Manager's ChargeGained voice preset. The legacy `gameStateCD` flag still loads as `Ready`, and exports keep both fields.
- Added a "Pick from Cooldown Manager" skill picker to the cooldown/cast alert editor. It lists the current specialization's Cooldown Manager abilities (Essential, Utility, Tracked Buffs, Tracked Bars) with their category and spell name, and selecting one fills the spell ID, spell name, and base cooldown through the existing autofill path. The picker is searchable and is disabled in combat or while the CDM catalog is unavailable, since Cooldown Manager data cannot be read there; it rebuilds when combat ends or when CDM data loads while the editor is open.
- Added an experimental game-cooldown-state mode for non-fixed-CD alerts: a new "Game CD state" checkbox queues the spell on cast success and watches the `C_Spell.GetSpellCooldown` / `GetSpellCharges` NeverSecret booleans in the addon's own update loop, announcing on the client's exact ready edge without reading secret cooldown numbers. Readiness uses the `not (isActive and not isOnGCD)` predicate, so a cooldown that ends while the player is still on a GCD announces immediately instead of waiting for the GCD to finish (two consecutive ready ticks filter transient `isOnGCD` reads). It deliberately never registers Blizzard's `SPELL_UPDATE_COOLDOWN` / `SPELL_UPDATE_CHARGES` events, because sharing those secret-sensitive events taints the CooldownViewer handlers in combat (observed as forbidden-table and secret-number errors). Fixed-CD timing is skipped for those entries, GCD-only casts are dropped after a pending window, charge spells announce when recharging returns to max, and the flag survives save/load and import/export. Regression coverage in `tests/test_game_state_watch.lua`. The editor disables the condition operator/time (and the text "Show cooldown countdown" option) for game-state entries, since there is no countdown to compare and only the action selection is meaningful.
- Added a separate event-voice trigger for party or raid member deaths while retaining the existing player-death trigger. It detects connected group units changing from alive to dead, excludes the player and feign death, and runs its 0.35-second ticker only while that trigger is configured and the player is grouped.

## 1.0.226 - 2026-08-26

- Fixed globally stored event alerts dropping out of a scoped collection when reordered against another entry in that collection. Entry targets now resolve their real collection location across all scopes, preferring group membership over global root layout metadata.
- Fixed top-level alert creation inheriting a stale collection destination after a collection-targeted save. Explicit root creation now remains outside collections, and unused duplicate helper chains plus a stale move-controller wrapper were removed.
- Fixed collection-targeted creation losing membership when globally stored alerts are created from a class/spec collection. The type selector now carries its destination explicitly, and global event entries can be dragged out of, reordered within, or moved back into scoped collections.
- Fixed stale collection ID counters overwriting an existing group when a new group was created. Group IDs are now synchronized against every saved scope before creation, import, or cross-scope movement, preserving existing groups and their movable entries.
- Fixed top-level group creation inheriting the selected group as an implicit parent. The Add Group button now always creates a root group; only the explicit context-menu child-group action creates nesting.
- Added event-voice choices for role-check start, an incoming summon awaiting the player's confirmation, and an incoming resurrection targeting the player.
- Collection context creation now opens the alert-type chooser for cooldown, cast-success, or event alerts, and saved-entry context menus can move alerts directly into any existing collection without drag-and-drop.
- Event voice saved entries are now distinguished by their load locations. The same event can keep separate world, Delve, dungeon, or raid variants, while overlapping conditions (including broad modes that cover an existing specific selection) are rejected to prevent duplicate playback.
- Runtime selection, collection deletion, deletion markers, legacy migration, and single/collection imports now retain the exact event load-condition variant. Disjoint variants import independently; exact imports replace only their matching variant; overlapping imports are rejected without modifying existing entries.
- Added a "Specific current-season instances" mode for event voices. Current-season dungeons and raids are populated dynamically and support selecting multiple instances; old-season instances are excluded from the list and cannot match through stale IDs or saved names.
- Specific-instance selections preserve stable dynamic IDs and display-name snapshots through editor reloads and all import/export paths, while runtime matching remains event-driven and uses the same cached season catalogs.
- Added event-voice load locations for world content, Delves, five-player dungeons, and raids. Dungeon and raid locations can target any instance or the current season; seasonal dungeon data comes from the live Challenge Mode catalog, while raids use the live Group Finder current-season filter, with no maintained instance-ID tables.
- Event location checks run only when an event fires, season catalogs are warmed and cached outside combat, missing catalog data fails open, and the saved list reflects the current location without adding timers, tickers, or `OnUpdate` work.
- Preserved event load locations and instance modes through editor save/reload and every import/export shape, with regression coverage for legacy defaults, Delves, seasonal dungeons/raids, runtime dispatch, codec round trips, and API-unavailable fallback behavior.
- Added drag ordering and collection membership for Cooldown Manager saved entries while keeping their runtime preset records separate from list-layout metadata.
- Deleting a collection now also removes its contained Cooldown Manager presets, including built-in preset disablement and pending native-alert cleanup; stale CDM collection references are discarded automatically.
- Collection and full exports now preserve CDM membership and the referenced CDM preset records, with regression coverage for grouping, ungrouping, deletion, and stale-reference cleanup.
- Kept CDM collection validation out of combat hot paths and replaced per-reference full preset scans with O(1) indexed checks; every saved-list refresh now builds one revisioned CDM row snapshot shared by all collection scopes.
- Fixed ordinary collection imports failing on an empty CDM profile payload, and included imported CDM presets in collection import counts.
- Added an optional fixed-cooldown text countdown that appears immediately on use, preserves the configured text (or falls back to the spell name), formats long values such as `1m5s`, and refreshes visible text only once per displayed second.
- Split the talent load requirement from the talent that changes fixed CD: each now has its own checkbox, talent ID, and name. Legacy combined-talent saves/imports are translated automatically.
- Kept countdown work out of ordinary entries and measured the optional branch at about 0.03 ms per combat second even with 30 simultaneous countdowns; added countdown, split-talent, legacy migration, and import-field regression coverage.

## 1.0.219 - 2026-08-14

- Replaced generic `BAG_UPDATE_DELAYED` refreshes with targeted state checks: only active monitored bag items are compared, and only a meaningful load-state transition (absent to present or present to absent) is correlated with closing mail, completing a player trade, or closing the Alchemy profession UI. Unrelated item changes and quantity-only changes no longer rebuild the runtime. A delayed login refresh remains as the startup fallback.
- Stopped marking the bag cache dirty during ordinary profile rebuilds and combat exit; equipment-dependent entries still retain their separate equipment-change handling.
- Added regression coverage for the new inventory event routing, Alchemy-only profession close handling, and delayed login refresh.

## 1.0.217 - 2026-08-12

- Added 12.1.0 (121001) to the supported game versions in both addon TOCs (and the embedded LibSharedMedia-3.0 TOC), keeping 12.0.5/12.0.7 compatibility.

## 1.0.216 - 2026-08-12

- Cast-success alerts now treat "Check Talent" as a hard load filter: when the entered talent is not currently selected, the alert is not loaded at all (mirroring Check Equipped / Check Bags). The "Load only when selected" toggle is locked on for cast alerts, and the "CD Changes To" field stays hidden there.
- The saved-list "loaded" tag now accounts for the talent condition: alerts whose talent is not selected show as unloaded, matching the runtime behavior.
- Exposed IsTalentSelected through the public API for the config addon; updated the talent load filter regression tests.

## 1.0.215 - 2026-08-12

- Added a talent load filter for cooldown and cast-success alerts: with "Check Talent" and "Load only when selected" enabled, the alert is only loaded while the entered talent is actually selected (mirroring Check Equipped / Check Bags for items). Without the load filter the alert always loads, keeping the old behavior.
- The talent row now also appears in the cast-success editor; the "CD Changes To" field stays cooldown-only and is now optional (empty keeps the fixed CD and uses the talent purely as a load condition).
- Cooldown Manager runtime and cast-success configs apply the filter at build time; exports preserve the new field.
- Added regression coverage for the talent load filter (tests/test_talent_load_filter.lua).

## 1.0.214 - 2026-08-12

- Gated the Bloodlust `UNIT_AURA` handler behind a config-level flag: when no Bloodlust alert channel is enabled, the most frequent combat event now costs a single boolean check (about 20 ns) instead of scanning every aura update for exhaustion effects.
- Bounded retained visual-alert frames: at most 12 hidden slots are kept; older inactive frames are released before new ones are allocated, so long sessions cannot grow memory without limit.
- Added a hot-path micro-benchmark (tests/bench_hotpath.lua): 30 active cooldown records cost about 0.2 microseconds per record per tick.

## 1.0.213 - 2026-08-12

- Removed 30+ dead functions across both addons (leftovers from refactors: legacy Cooldown Manager sync plan builders, old visual alert APIs, compatibility stubs, unreferenced helpers), shrinking the loaded Lua sources.
- Cached the max-charge value on active cooldown records so the hot tick loop no longer converts `cd.charge` up to three times per record per tick.
- Removed a duplicate `FirstNonEmptyPath` evaluation in the editor's custom sound path resolution and an unreachable sound-path fallback chain in the notifier.
- Merged duplicate localization keys whose later overrides silently won before; the effective values are unchanged.

## 1.0.212 - 2026-08-12

- Hardened the searchable voice dropdowns (editor SharedMedia search and Cooldown Manager voice search) so opening them always lands on the currently selected voice. An empty search no longer resets the list to the top, and the jump to the selected item is the final step after the popup is shown — covering the case where the first open's initial search-box `SetText` fires `OnTextChanged` and re-layouts the list.
- Added regression coverage for the dropdown open scroll-to-selected behavior (first open, repeated opens, empty-search preservation, real-filter reset).

## 1.0.211 - 2026-08-12

- Fixed searchable voice dropdowns (editor SharedMedia search and Cooldown Manager voice search) opening at the top of the list instead of the currently selected voice on the first open. The initial search-box text assignment could fire `OnTextChanged` and re-layout the popup back to the top after it was already scrolled to the selection; search mode now starts before the jump to the selected item, so the jump always runs last.

## 1.0.210 - 2026-08-12

- Extended the voice toggle-clear to the Cooldown Manager's searchable voice dropdown: clicking the already-selected voice again cancels the selection back to the "No custom voice selected" placeholder instead of only replacing it.
- Cancelled Cooldown Manager rows return to the unconfigured state, stay out of the dirty-draft batch (so Apply All is not blocked), and disable Test/Save/Apply until another voice is chosen.

## 1.0.209 - 2026-08-12

- Placed the editor's searchable SharedMedia voice list on the same popup strata as the Cooldown Manager voice list, keeping it above the editor but below WoW's IME composition/candidate layer so typing in the search box no longer blocks the input method.
- Added toggle-clear to the editor's built-in and SharedMedia voice dropdowns: clicking the already-selected voice again cancels the selection (showing the placeholder) instead of only replacing it; a cancelled built-in selection no longer falls back to the default built-in sound.
- Added regression coverage for the dropdown toggle-clear selection logic.

## 1.0.208 - 2026-08-06

- Confirmed cooldown casts use the direct `spellID -> runtime entry` map; added regression coverage preventing unrelated saved cooldown configs from being read or activated.
- Stopped creating active cooldown timers for entries with every alert channel disabled, and retired timers as soon as all one-shot alert work is complete.
- Removed a duplicate runtime/cast-success configuration rebuild after saving a visual-group entry by persisting its visual identity before the normal save rebuild.
- Ignored bag and equipment refresh events unless the active configuration actually contains an item entry whose load rule depends on that inventory source.

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

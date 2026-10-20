# Trailbound 1.8.49

Learned profession recipes no longer return through saved trainer rows. Catalogues refresh on learning and reconcile delayed client data automatically.

## Trailbound 1.8.49 - same-session learned catalogue filtering

Fixed profession catalogue fallback reintroducing learned recipes: every reference name/rank is now marked as handled before learned filtering. Previously a learned reference recipe was removed but its saved trainer observation (often without a spellID) was then appended as an unmatched extra. Reference-backed observations can no longer bypass the learned check.

Systems' NEW_RECIPE_LEARNED handler now uses the event recipeID and optional baseRecipeID immediately, including when the crafting window/current profession is unavailable. Recipe scans only add confirmed learned=true values; stale/partial false replies cannot erase a positive learn event. Scans still never infer learning from purchase attempts. Trainer scans capture a readable spell hyperlink ID when exposed. Existing unknown trainer services remain until used/known confirmation.

Class trainer catalogue keeps its existing rank-aware filtering and now listens for LEARNED_SPELL_IN_TAB as well as SPELLS_CHANGED. Trainer updates and class learn events refresh immediately and schedule one coalesced 200ms follow-up to reconcile native trainer/spellbook caches. Follow-up re-scans trainer services only while the trainer is open, records recipes and refreshes both lists. Profession updates similarly schedule a bounded follow-up. No persistent polling or purchase hooks. Confirmed learned-recipe cache remains sticky; profession-unlearning/relearning cache invalidation is not changed by this patch.

Syntax and cumulative regression suite pass. Added same-session ID-less-trainer fallback regression, visible recipe-row removal after learn event, event base-ID capture, stale learned=false protection, class learned-rank filtering with future-rank preservation, and coalesced delayed class refresh tests. Native client event ordering still needs live confirmation. Versioned ZIP and live AddOns/Trailbound files updated/hash-verified; use /rl once. SavedVariables/migration metadata preserved.

Primary API reference checked: Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua NEW_RECIPE_LEARNED payload (recipeID, recipeLevel, optional baseRecipeID).

# Trailbound 1.8.48

Reload once to fix orphaned crafting-profit settings. Editors now remain inside a permanent options container and all close with the main window.

## Trailbound 1.8.48 - settings editor containment and close lifecycle

User reports Crafting profit estimates controls floating over the world after leaving options, sometimes following settings edits/profession opening. Shared editor host previously replaced the scroll frame's scroll child with each editor and only closed activeEditor. Reworked it to set one permanent editorContent scroll child at construction; every editor is parented inside that container, never directly swapped via SetScrollChild. Opening hides all other registered editors before selecting/parenting/showing the target and sizes the container to its content. Host close clears active tracking, explicitly hides every registered editor and hides the scroll area. Registered editors reject late OnShow events when the host is closed or they are inactive. No native profession/window methods changed.

Syntax and cumulative regression suite pass, with actual profit-settings mutations, repeated profit/chat switches, closing/reopening main options, profit refresh while closed and forced late shows. Checks assert constant scroll-child identity and zero editor swaps, correct parent containment and all-editor cleanup. Tests cannot confirm the exact native client detachment sequence; the new ownership avoids that path. Packaged and installed directly in AddOns/Trailbound with hashes matching source. /rl once loads the fix and clears existing stuck controls. SavedVariables and migration metadata untouched.

# Trailbound 1.8.47

Level-times background is transparent by default. Adjust it under Experience & travel. Catalogue price columns are inset clear of scrollbars.

## Trailbound 1.8.47 - level background opacity and catalogue price clipping

Level-times background defaults to fully transparent. New profile setting levelTimesBackgroundOpacity (0-1, default 0) controls only the backdrop and border alpha; frame/text alpha stays unchanged. Slider under Experience & travel applies live and persists with addon settings. Position/history and text colors are unchanged. Header now explicitly says Made by Jemai.

Profession catalogue scroll viewport was 295 wide but content/rows were 300, clipping the rightmost coin texture. Content/rows are now 285 with an additional 8-unit right inset on the 104-unit price column. Requirement column narrowed to avoid price overlap, and coin text does not wrap. Class catalogue also receives an 8-unit price inset and wider 104-unit price field, with row/content width 284 safely inside its 304-unit viewport. Dense row heights and red skill/level warnings remain.

Syntax and cumulative regression suite pass, including default/custom opacity without fading text and both price-column bounds. Versioned ZIP produced and runtime copied/hash-verified in live AddOns/Trailbound. /rl is sufficient; migration metadata and SavedVariables untouched. In-game rendering at the user's UI scale still needs confirmation.

# Trailbound 1.8.46

Use `/rl` after updating. Visit profession trainers once to record recipe skill requirements. Catalogue rows and profit summaries are compact; Search mats includes per-craft ingredient quantities.

## Trailbound 1.8.46 - compact catalogues and material search quantities

Profession trainer scans now retain GetTrainerServiceSkillReq name/rank separately as requiredSkill/requiredSkillName (not the unverified minimumSkillField in the static reference). Current profession skill and character level gate recipe names/requirements in red; unknown old requirements show Skill ? until a trainer visit. Confirmed records keep these values through reference matching, and sorting uses verified requiredSkill. Previously unrecorded requirements cannot be reconstructed reliably from the static reference, so ask the user to revisit each trainer once. Trainer level capture supports both native info level return and the older dedicated level API.

Profession catalogue rows shrink from 44 to 29 UI units with 22-unit icons, single-line names, skill/level requirements below, and a separate price column. Header is one line showing current skill and recipe count. Class trainer spell rows shrink from 46 to 30 with smaller icons and single-line names; unmet levels now make both the name and level red. Price sits beside the level on the second line. Class pane is slightly wider to reduce name truncation. Tooltips preserve full spell/recipe names.

Embedded crafting profit shrinks from 175 to 110 height, max width 340; trainer profit uses the same compact summary plus one-time learning fee (132 high). Four visible lines show material/vendor values, vendor profit, conservative AH net, cut and deposit. Full output/yield, AH sale, source/age, missing inputs and deposit-refund distinction remain on hover. Buttons are 20 high. No profit math changes or free-input assumptions.

Search mats now builds exact-name quantity-aware terms, aggregates duplicate reagent slots, and uses installed Auctionator public MultiSearchAdvanced with searchString/isExact/quantity. Quantities are total inputs for one craft by default, including materials already owned (same semantics as Auctionator's own craft reagent search); E.SearchMats accepts an optional craft count for callers. No automatic purchasing. The older exact-name API fallback prints required quantities; native AH queue also prints and retains each requested amount because browse queries have no quantity field. Unavailable quantities abort rather than assume one. Auctionator shopping list uses Trailbound caller name. Searches still queue until AH opens and preserve exact required ingredients.

Syntax and cumulative regressions pass, including skill-requirement capture, static-reference-field rejection, live rank color updates, actual compact profession/class rows, red future spells, compact profit geometry, queued exact quantity searches, duplicate ingredient aggregation and craft-count multiplication. Runtime files copied directly to AddOns/Trailbound; /rl is sufficient. Existing migration metadata and SavedVariables untouched. In-game catalogue layout and real Auctionator shopping behavior remain to verify.

Primary references inspected: Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua (skill, rank, hasReq returns of GetTrainerServiceSkillReq); installed Auctionator Source/API/v1/MultiSearch.lua and ShoppingLists.lua plus Source_Mainline/CraftingInfo/Professions.lua (advanced quantity-aware exact reagent search). No external addon source copied.

# Trailbound 1.8.45

Restart WoW after upgrading to this renamed folder, then open `/tb`. The old `/fa` commands are removed. Keep the small saved-data import addon enabled so existing characters retain their history/settings.

## Trailbound 1.8.45 - UI clarity, smooth swings and physical rename

Runtime source/install is now Trailbound/ with Trailbound.toc and Trailbound*.lua files. All runtime media references use Interface/AddOns/Trailbound/. Main addon ADDON_LOADED identity is Trailbound. Only /tb, /trailbound, /tbo, /tbedit, /tbplay, /tbbank, /tbbags, plus generic /rl, /junk and /copychat remain. Removed every /fa-derived slash registration, including fabank, fabags and the hidden old buff-tracker command. Internal globals/secure frame names intentionally remain stable so existing ring macros and SavedVariables do not break; these are not visible commands or filenames.

IMPORTANT SAVE MIGRATION: WoW SavedVariables filenames follow addon folder names. migration/ForeverAssist/ForeverAssist.toc is a metadata-only dependency declaring the old account/per-character SavedVariables. Its old files therefore load before Trailbound, whose new saved files take precedence when present. No legacy Lua, UI or commands are loaded. Keep this tiny metadata folder enabled for old characters that have not logged in since the rename; do not disable it automatically after one character migrates. Stable data keys remain ForeverAssistAccountDB, ForeverAssistGoldDB and ForeverAssistDB; TrailboundMigrationDB only marks the new save generation. No account/character tables are cleared or replaced during migration. New addon folder discovery requires a full client restart. Actual saved-file load order needs live confirmation; mock tests cannot replace a real character switch.

Use tools/install.ps1 to install directly into the beta AddOns directory. It backs up the original installed old folder into dist/ForeverAssist-before-Trailbound-1.8.45.zip once, copies/hash-verifies Trailbound, verifies the exact old absolute target is inside AddOns and not linked, replaces that old runtime folder with metadata only, and leaves WTF completely untouched. Re-running retains the original backup. The distribution ZIP includes Trailbound/ and the one-file migration directory. Never leave old full runtime code loading beside Trailbound.

Swing editor captions and texture/color button labels are initialized directly and refreshed in a single OnShow handler plus explicit opening refresh, avoiding hook replacement/open-order issues. Slider refreshes do not write settings. Live fill and preview now update from GetTime every display frame; numerical captions update only when the displayed tenth changes. The slower native/layout refresh remains separate. Tests verify progress at 8ms intervals and label population. Need in-game confirmation of native rendering and options clipping.

Navigation uses literal feature names: Quests & training; Bags & vendors; Combat & recovery; Experience & travel; Professions & prices; Minimap & sound. Roman numerals, CHAPTERS, AT YOUR CAMP and field-journal tagline removed. New tagline describes quality-of-life tools. Flight timing moved to Experience & travel; XP and level settings moved there too. Profession catalogue and profit toggles/pricing settings are grouped together, with gathering access there and under minimap. Search keywords route to the updated pages. Embedded editors, header Edit mode, profiles and shortcuts remain.

Shared addon-only Friz font objects (TrailboundText/Small/Heading/Title/Muted), warm text and gold headings now cover addon windows and HUD labels. Shared panel helper gives level times, Edit mode previews/toolbar and standalone options matching warm surfaces/borders. Existing literal panel colors aligned with the palette; user-chosen swing colors, class colors, XP/rested/quest colors and red skill warnings remain meaningful. Native Blizzard global fonts and health/status managers are untouched.

Level-times HUD suppresses missing milestones entirely, packs known entries within the latest ten levels, and sizes to visible rows. No Not recorded rows or note. Recorded history remains per character and unchanged. All 21 Lua files and cumulative regressions pass, including smooth swing timing, immediate editor labels, six options pages, hidden unknown milestones, command cleanup, shared styling and migration table identity/idempotence. Live reload/character-switch/UI validation is still required. No GitHub operations.

# Trailbound 1.8.45

Open with `/tb` or `/trailbound`. Use `/tb levels` to toggle the movable level-times window, or find it in IV. The journey. The options finder helps locate settings.

## Trailbound 1.8.45 - level milestones, round nodes and field-journal options

The user chose Trailbound as the new name. Addon list, settings registration, launcher, chat prefixes, header, edit toolbar and player help now use Trailbound. Main commands /tb and /trailbound; /tb edit, /tb levels, /tb rings, /tb nodes and /tbplay are available. /fa, /foreverassist, /fao, /faedit and /faplay remain compatibility aliases. The runtime folder, TOC filename, Lua globals, secure ring/macro frame names and SavedVariables intentionally remain ForeverAssist: changing these would break reload-only upgrades and risk character/account data. Do not install a second renamed folder alongside it. Distribution ZIP is Trailbound-VERSION-Forever.zip with the existing top-level ForeverAssist/ install directory.

Options now uses a warm leather/field-journal treatment, a custom original route-and-mountains medallion, Friz title, gold/brown shared buttons, numbered topical chapters, calmer descriptive labels and a settings finder. Search matches familiar terms such as auctionator, gold, pet, xp, levels and keybind to their section/tool. Empty results are explicit; Escape clears search. Header Edit mode and stable embedded editor host remain. Shared buttons were deliberately restyled at the user's request (supersedes old slate/teal preference).

ForeverAssistLevels.lua records character.levelTimes[level]={at=totalPlayedWhenLevelBegan,estimated=optional}. TIME_PLAYED_MSG recovers the current milestone exactly as total minus time-this-level, including first install. Level 1 starts at zero. Earlier unknown milestones say Not recorded; no historical timestamps are invented. PLAYER_LEVEL_UP records a provisional extrapolated /played and requests an exact server sample, replacing the estimate on reply. Existing Play module requests /played at login, so there is no extra login request. History persists per character; all rows are retained but the HUD shows levels max(1,current-9) through current. It grows up to ten rows and displays advancing /played and This level clocks. Drag saves profile levelTimesPosition; global Edit mode adds the tenth mover. The Journey chapter checkbox or /tb levels toggles visibility. Missing historical levels cannot be recovered from the server.

Gathering icons remain compact 14-unit frames; item textures are masked with an original antialiased circular TGA, dark disc and thin gold/red ring instead of square backdrops. Native item art, ground pinning and skill colors remain. New media is original code-rendered geometry; no external artwork bundled.

Syntax and cumulative regression suite pass: current-level recovery, provisional/exact level-up recording, honest missing history, live clocks, height growth and ten-row limit, position saving, reload persistence and character isolation, tenth layout mover, round texture masking, command aliases, settings finder and all existing gold/ring/combat/AH behavior checks. Live verification still needed for actual profession/UI shapes, history timing around level events, round masks and new theme. Installed in the live beta AddOns folder; SavedVariables preserved. No GitHub commit/push.

## 1.8.43 compact ground-fixed node icons and stronger sparkles

Minimap icon frames reduced from 26 to 14 UI units (12-unit item picture), retaining skill colors and thin border. Observed nodes now have session-only map-yard pins. Probe batches capture public player/map geometry; sample positions are reprojected to the latest view before grouping. Matching same-type nodes reuse their existing ground coordinates rather than jumping to each new coarse sample centre. Each display frame reprojects ground pins as the player moves, including minimap rotation and zoom, so icons move with the terrain instead of sliding independently or stepping only at scan completion. They cannot remain at fixed screen coordinates while the map scrolls. Missing map geometry uses unpinned tooltip results; zone changes hide old-map pins, empty scans remove pins, and combat/disabled/error paths clear them. No spawn database or persistent world-node storage. Nearby identical overlapping nodes can still merge; first-observation position is limited by the tooltip probe grid.

Sparkles increased from 7 narrow particles in an 80x60 area to 20 larger/brighter particles across 130x120 UI units, with a 0.3 minimum alpha. Emitter moved from 20 above the game-object plate bottom to 85 below it, aiming over the node rather than the overhead interaction icon. Nameplate geometry varies with the camera/client; visual placement still needs live confirmation. Interaction detection range remains unchanged.

Syntax and cumulative regression checks pass. New checks verify compact icon geometry, unchanged ground pin under probe jitter, continuous following during player movement, rotating-map and zoom transforms, inverse projection, zone exclusion, and denser/brighter/lower sparkle geometry. Package and live beta AddOns files updated; no SavedVariables reset or other addon changes.

Primary API references checked: Blizzard source mirror APIDocumentationGenerated/MinimapDocumentation.lua (GetViewRadius yards, IsRotateMinimapIgnored) and MapDocumentation.lua (player position and map world size). Own original projection/matching implementation. Actual Forever map radius/rotation and sparkle placement still require in-game verification.

## 1.8.42 stable minimap probes and single-node grouping

User reports intermittent hover-dependent icons, duplicate copper icons for one vein, and poor appearance. Scanner was missing SetUsingSoftCursor(true): explicit probe positions require the minimap soft cursor. Each bounded probe batch now enables it, releases it before data processing/rendering even after rejected native calls, and restores the real cursor position. Combat/real-hover pauses remain. Structured TooltipInfo empty/nil results no longer trigger the display-tooltip fallback: empty means no readable dot, while display tooltips can contain quest-addon lines. Private fallback remains only for clients lacking the structured API. Debug also names the last recognized node separately from incidental tooltip lines.

Raw same-node grid hits are deduplicated and grouped by connected adjacent samples, then centered on each patch bounding box. This replaces order-dependent moving-centroid clustering that could split one dot into several markers. Separated same-name patches stay separate; touching identical-node patches may still merge. Probe budget is 48 points per 20ms tick to reduce movement smear. Partial scans restart on real minimap hover. Item icon interior is now 24 UI units instead of 14, with less cropping, a thin gold/red border, dark backing and texture snapping disabled where supported. These are native item icons, not newly generated artwork or higher-resolution source assets.

Cumulative syntax/regressions pass, including explicit soft-cursor-dependent probes with unrelated real-mouse quest text, release after native error, no stale fallback on empty structured data, one broad footprint yielding one ore in either traversal order, separated veins, and the larger icon geometry. In-game confirmation is still needed. Versioned package and live beta AddOns install updated. SavedVariables and other addons untouched.

Primary implementation capability reference checked: NodeSight author's ScanSome in https://github.com/Krelock/NodeSight/blob/main/NodeSight.lua confirms soft-cursor use around probes. Own scan batching, connected-component grouping and renderer changes; no third-party implementation/assets bundled.

## 1.8.41 minimap node identification compatibility

User reports a vein still has only a native yellow dot. Removed the tracking-menu hard gate: older tuple-shaped entries, empty or incomplete menus cannot block reading visible tracking dots. Tooltip node names now strip inline atlas/texture decoration as well as color codes, and split multiple names per line. Added a private hidden GameTooltip SetMinimapMouseover fallback when structured TooltipInfo does not return readable lines. No shared tooltip hooks or native dot suppression; unknown/restricted nodes stay unchanged. Existing combat and hover pauses remain.

/tb nodes prints version/status, active tooltip reader, completed scans/probes/matches/icons and the latest public minimap text. If the user's live client still shows yellow dots, ask for that output near a vein, out of combat and with the mouse outside the minimap. This patch addresses concrete compatibility gaps but the exact failure on their client has not been observed directly.

Syntax and cumulative regressions pass, now including decorated/multiline names, tuple and empty tracking menus, and private tooltip fallback visibility. Packaged and copied runtime files directly into the beta AddOns folder. Live verification remains outstanding. API capability references rechecked: Blizzard_Minimap/Mainline/Minimap.lua (native tooltip mouseover), NodeSight author's minimap probe calls; no third-party source bundled.

## 1.8.40 shortcuts, inline crafting profit and gathering visuals

- Added /rl (reload), /fao (options), /faedit (layout edit mode), without claiming existing slash aliases. Removed the chat Copy button; URL clicks, Ctrl-click link copying and /copychat remain.
- Crafting profit is embedded in the bottom right of the profession crafting tab, with Search mats and Settings buttons. Full calculation details appear on hover. Trainer profit retains its trainer panel. Verify placement with long reagent lists and client-specific profession layouts.
- Display options now has Herb & ore icons / sparkles. Visible tracked minimap nodes are identified through the client's minimap tooltip probe, and receive item icons; known insufficient gathering rank makes icons red. Find Herbs / Find Minerals must be active. No spawn database or hidden object enumeration. English classic node names and localized herb item aliases are supported; new beta nodes/requirements and localization need live verification. Closely packed identical dots may merge. Sampling pauses in combat and on minimap hover.
- Nearby known gathering game-object nameplates receive animated sparkle overlays. Enables softTargetInteract=3, SoftTargetIconGameObject=1, SoftTargetInteractArc=2, SoftTargetInteractRange=30 outside combat. This requests all-around interaction detection; it does not automate gathering, extend gathering reach, or guarantee visibility at 30 yards. Backups live in per-character gatherInteractRestore (not profile snapshots). Disabling sparkles restores only settings still equal to the applied value, preserving manual changes. Native nameplate alpha/scripts remain unchanged. Unsupported APIs fail quietly.
- Syntax and cumulative mock regression checks pass, including inline parent/anchors, reload dispatch, gathering skill colors, minimap probe/render, combat guards, object-only sparkles and reversible CVars. Live minimap and object-nameplate support, overlay position and profession placement still require the user's client. Installed directly into the beta AddOns folder; no GitHub changes.

Capability references inspected: Blizzard source mirror Controls.lua (Enable Interact Key), APIDocumentationGenerated/TooltipInfoDocumentation.lua (GetMinimapMouseover); NodeSight author's public repository and project page for minimap probing and game-object nameplate API capabilities. No third-party implementation/assets bundled. Own tooltip-grid clustering and animated overlay implementation.


# Trailbound 1.8.40

Changes in 1.8.40:

- **Edit mode** is a themed button in the options header beside X. External buff settings no longer fail when opening the embedded editor.
- **Flight-path timer:** first trips learn route duration; repeat routes show an approximate remaining time and total. Move the timer in Edit mode. Toggle it under Combat & recovery.
- **Chat appearance:** options for class/race icons, compact channel labels, font size, fading and spacing. Existing class name colors and normal item/player links remain. Click URLs, Ctrl-click other links, or press Copy above chat, then Ctrl+C in the copy window. Unknown/restricted sender identities receive no icons.
- **Crafting profit:** crafting/trainer windows show material cost, vendor return/profit, estimated AH sale, cut, deposit and profit. Recipe rows show estimated AH profit. Sources can be Auto, Auctionator, TSM market or locally observed AH prices. Unknown ingredients/fees stay unknown. Training fees are listed separately.
- **Search mats:** queues the selected craft's required materials and searches them when you open AH. Uses Auctionator multi-search when available, or serial native browse searches. It never buys or crafts automatically.

Crafting profit settings control price source, age cutoff, AH cut, estimated deposit rate and listing duration. Deposits are labeled when estimated. Both the requested conservative result (deposit deducted) and successful-sale result (deposit refunded) are shown. Fee presets need to match your AH; estimates do not guarantee sales. Some trainer schematics or multi-choice recipes may be unavailable until their data is exposed/cached. Flight, chat and profession integrations pass mocked checks and still need live testing.

Changes in 1.8.38:

- **Edit mode** in options (or `/tb edit`) opens draggable previews for all eight addon HUD displays. Move them, then click **Done — lock positions** or press Escape. Combat ends editing automatically. Positions use your active addon profile.
- The important buff icon tracker is hidden for now. **External buff notices** instead show important timed buffs received from another player, such as “Power Infusion on you for next 15 seconds.” Counts follow the actual remaining duration. Your own buffs and unconfirmed/restricted casters are excluded. Use edit mode to move the text.
- **Swing timer editor** has live width/height/spacing/text-size/opacity sliders, weapon-name and seconds toggles, reverse fill, flat/shaded textures, four color choices and reset. Changes preview immediately; close the editor to finish.

Incoming-buff notices require readable aura and caster information; they hide when the client restricts it. These changes pass mocked checks but need in-game verification.

Gold persistence (1.8.37): logout no longer reads and force-saves a possibly zero teardown balance. Last recorded gold remains intact across character switches; teardown polling, late money events and bag snapshots are blocked until world entry. Real money changes still update normally. If a previous release already saved zero, log that character in again to record its current balance. Use /tb gold to check saved character balances. Live character-switch verification is still required.

Window correction (1.8.36): restores Blizzard's panel registration and opening logic after character-window taint errors were found in the game log. Adds drag handles for the windowed map/map-based quest log, quest details and Legacy Points panel candidates. Drag the center of the title area. Native panel coexistence limits apply again; unlimited simultaneous opening is disabled. Positions remain saved per character, but Blizzard may reposition panels during layout changes. A /reload is required; the correction still needs live verification.

Movable windows (1.8.35): drag the center of a standard window's title area to move it. Spellbook, professions/crafting, vendors, talents, character, trainers, quest dialogs, bank/mail/auction, social and other ordinary panels can stay open together. Positions save for each character. Existing close buttons and Escape still work. Movement/setup waits until out of combat, and service windows still close when the game ends their interaction. Full-screen map, Settings, Game Menu and Edit Mode keep Blizzard's behavior. This feature needs live-client verification, including taint checks.

Options (1.8.34): the main settings window title now shows the installed addon version.

XP colors (1.8.33): green earned XP, yellow completed quest rewards and blue rested XP share the thicker continuous track. Bonus segments follow earned XP and are capped at the current level's end; full bonus amounts remain in the statistics. No divider marks.

XP display (1.8.32): one thicker, continuous yellow XP bar with a simple dark track. Level, XP and percentages appear inside; level/session times above; leveling estimates, quest completion and rested percentages below. Detailed statistics remain in the hover tooltip. Existing saved position and lock are preserved.

Ring keybinds (1.8.31): Assign key and Clear key apply only to the current character. Ring definitions and macros remain shared. Existing shared keys migrate once to the first character loaded after updating; other characters start without ring keybinds. Character keybinds are stored separately from shared addon profiles.

Ring macros (1.8.30): login and ring rebuilds no longer create macros. Creating a ring or clicking Pick up macro reuses its existing macro, ignoring trailing newlines, and creates one only if missing. Existing duplicates are left untouched; remove extras manually in WoW's macro window.

Junk Manager (1.8.29): right-click an item row to remove that item type from the list while keeping its stacks in your bags. Exclusions persist across reloads and protect those items from automatic junk selling, including gray items. Drag an item back into the window to add it again. Shift-click also removes from the list. The Delete lowest stack button still deletes an actual bag stack after confirmation.

Ring action-bar macros (1.8.28): each ring automatically gets a macro when a free macro slot is available. In the Rings editor, select a ring and click **Pick up macro**, then drop it onto an action bar. Macros toggle open/closed independently of the addon keybind's hold setting. Macro creation/pickup requires leaving combat. Existing macros are reused without overwriting user macros; account slots are preferred, with character slots as fallback. Deleted rings leave their old macros inert; remove unwanted macros in WoW's macro window. Live action-bar/combat verification is still required.

Follow Windows audio output is enabled by default under Display & minimap. It selects WoW's System Default output (Sound_OutputDriverIndex=0), listens for VOICE_CHAT_OUTPUT_DEVICES_UPDATED, and restarts game sound after a 0.75-second quiet interval. There is no periodic polling. A 5-second restart guard ignores immediate feedback events; very rapid device switches during that guard may require Refresh audio or /tb audio. Disabling stops pending work and leaves the current output selection in place. It does not change microphones, volume, or Windows settings. If this client does not emit the event, use Refresh audio. /tb audiodebug reports the setting, supported event and last status. Live Windows switching needs verification.

XP suppression now discovers the manager's anonymous bar containers and covers their nested decorative frames as well as their regions. Actual reputation/honor bars are excluded. Decoration alpha restores when another bar is selected or custom XP is disabled. This is a targeted change, not a confirmed live fix for every leftover mark. /tb xpdebug now includes nested child frames to help identify remaining artwork, including a possible separate XP bar supplied by another addon. Native manager/layout/Edit Mode methods remain unchanged.

A separate versioned VS Code project archive includes the same addon source, regression checks, check/build commands, and AGENTS.md plus docs/HANDOFF.md for continuation.


This update fixes the button-skin startup error on clients whose texture setters reject nil. The skin hides existing textures without calling those setters. Right-click on the minimap opens the addon launcher without sending a native minimap ping; left-click retains the existing native handler. Another addon replacing or hooking minimap mouse scripts can still affect this behavior.

Drag the Sit at campfire button outside combat to move it; its position is saved. Click class buff and gathering tracking reminder icons to cast the displayed spell on yourself (the spell name uses the highest learned rank). Pet and sleeping-bag notices remain informational. While unlocked, reminder icons only provide the position preview. Secure reminder actions and layout refresh outside combat; the last safe set remains usable during combat unless Hide in combat is enabled, then the secure visibility driver hides it. Reminders refresh on leaving combat.

Validation: Lua 5.1 syntax and simulated full options construction, strict non-nil button asset API, left/right minimap dispatch, saved campfire drag position, secure self-cast tracking attributes and combat update guard. In-game rendering and secure spell execution still need live verification.


Latest update: ring deletion with a second-click confirmation removes the saved definition and its keybind, and the editor supports an empty ring list. Default Warlock pets and Hunter pets rings automatically populate with learned, class-appropriate abilities; Hunter pets uses only the highest learned Mend Pet rank. Pet defaults are seeded once, preserving existing rings and respecting later deletions. Text buttons use slate/teal styling with matching hover/disabled states. Embedded editor close/back buttons are removed, leaving the main settings close button and sidebar navigation. Experience-bar enable and position-lock checkboxes now live in Display & minimap preferences, with no separate sidebar editor. XP position is locked by default; uncheck Lock experience bar position to drag it.

Close WoW, extract the ForeverAssist folder into the Forever game's Interface/AddOns folder, replace the previous version, and restart the game. Keep your SavedVariables files to preserve settings.

## New-character Edit Mode workaround

The user reports repeated CompactUnitFrame secret-health errors after creating a character and changing Blizzard's Edit Mode profile. They also report that /reload stops the spam. After saving the layout, use /reload once if this happens. This is a workaround; the underlying taint origin is not confirmed. ForeverAssist does not capture or load Blizzard interface profiles. No reload occurs automatically, and the addon does not patch Blizzard health comparisons or disable error reporting.

If XP decorations remain visible, run /tb xpdebug and provide its output. It lists known XP frames and nested children, their alpha and region atlas names; it does not inspect health or alter the frames.

## Icon design

The new icon is an independently generated compass-arrow and trail badge, with teal/gold accents and a dark slate/silver surround. The built-in image tool created the artwork; the game asset is Media/ForeverAssistIcon.tga, 128×128 RGBA with transparent outer pixels.

Generation prompt: “Use case: logo-brand. Asset type: one original square game-addon icon for ForeverAssist, intended to read at 32 pixels and 48 pixels. Create a distinctive compact fantasy utility emblem: a bold angular teal compass arrow pointing northeast, a short curved gold trail with two large trail dots below it, set within a simple dark slate round shield badge with a thin silver rim. Restrained hand-painted metallic depth, very crisp clean silhouette, almost flat visual hierarchy, bright teal and warm gold accents, spacious bold forms. Single centered emblem occupying 85% of canvas. No lettering, no words, no infinity loop, no dragon, no globe, no clock, no ornate filigree. Do not reference or reproduce any Blizzard, World of Warcraft, or Forever branding. Transparent background outside the badge, genuine alpha. Deliver only the finished emblem, not a mockup or multiple variants.”

## Future spells

Open your spellbook to see unlearned class-trainer spells and ranks through level 60. Green marks levels reached; gold marks future levels. Talent-granted abilities, their talent-dependent ranks, passive spells, triggered effects, and non-trainer reference records are excluded. There are no Class or Riding tabs. Hover for the spell tooltip; visit a trainer to add current prices.

Eligibility uses factual classic trainer IDs from https://github.com/fusionpit/WhatsTraining/tree/master/Classes/Vanilla , with Forever levels and names retained from https://github.com/MAF2414/wow-forever-talents (client 1.60.1.69876, September 16, 2026 snapshot). Only IDs, faction and race facts were extracted from the trainer reference; its code and costs are not bundled. The filtered reference has 1,140 spells across nine classes. Live class-trainer observations can add confirmed Forever-specific services, subject to passive/talent filtering. The static reference can omit new or changed Forever training until observed in game. Prices are never inferred from resource costs.

## Junk

Gray items sell automatically when you open a vendor if Auto-sell gray items is enabled in /fa. Holding Shift when opening the vendor bypasses automatic selling. Prices that are not cached yet are requested and retried. Sales stop if the vendor closes, combat starts, an item is on your cursor, or repair mode is active.

/junk opens a movable junk manager. It lists bag items that are gray or whose item type you have marked by dropping an item anywhere in the junk window. Marked types are shared across your characters. Shift-click a row to unmark its type; gray items remain in the list because they are automatically classified as junk.

The list is sorted by total vendor value per stack, lowest first. Prices shown are for the whole stack; stack quantities are shown next to item names. Items without loaded prices sort last, and deletion is disabled until prices are known.

Sell listed items sells the listed stacks with positive vendor value while a vendor is open. Manually marked non-gray items are sold only through this button. Delete lowest stack asks for confirmation and deletes the ENTIRE first, lowest-value stack. It rechecks the item identity and stack count before deletion. Nothing is automatically deleted.

## Named account profiles

/tb profiles opens ForeverAssist Profiles. Save / overwrite stores only addon settings. Blizzard interface preferences, party/raid frame options, action-bar toggles, CVars and Edit Mode layouts are not captured or loaded. Old interface snapshots are removed from addon profiles on upgrade without applying them to the game.

Default shares addon settings across characters. Named profiles remain explicit snapshots, and loading one gives the current character its own addon settings copy. Profile loading is refused during combat. Profiles cover the same WoW account SavedVariables environment.

Extended camera zoom applies on login. Quest-object highlighting is changed explicitly through its control. Loading addon profiles does not apply these native settings. Existing native layouts or settings changed by older releases remain under WoW's own controls.

## Saved character records

Addon updates preserve character bag, bank and money records in SavedVariables. Replace the addon folder while WoW is closed and keep the WTF/SavedVariables files. Initialization retains offline characters and seeds recovery backups. Failed item reads, loading-zero capacities and early loading money values preserve previous data. Successful live reads still record real item withdrawals, removed bags and zero balances. Account bag archives and per-character snapshots provide recovery where saved data remain available; deleting the underlying SavedVariables files loses data the addon cannot remotely recover.

Choose an offline character in the saved bag or bank viewer and click Forget character. Confirming removes all their saved bag, bank, money and backup records, including old name/realm aliases. The current character is protected. Logging into a forgotten character again records it anew. WoW does not tell addons that an offline character was deleted, so removal is explicit.

## Validation

Lua syntax and mocked-client regression checks pass, including fixed-window editor switching, simplified buff settings and relocated rules, secure ring hold/release and toggle snippets plus mode persistence, an all-icons transparent launcher (55 icons), native error-handler/method/global identity preservation, filter forwarding and disable restoration, full options construction with strict callback validation, opening and navigating all settings pages, the camera button, legacy XP dividers and independent child decoration suppression/restoration, interface snapshot removal, new-character profile initialization, zero native interface reads/writes during the profile lifecycle, XP bar/border suppression, combat deferral, reputation-border restoration and gold recovery. Existing bag, bank, vendor, buff, reminder, timer and minimap checks also pass. This update has not been tested in a live WoW client; the exact origin of the reported compact-unit-frame taint is not confirmed.

## Changes in 1.4.0

The missing legacy GetCoinTextureString call is fixed everywhere. Money formatting uses the modern currency API when available and falls back to readable gold/silver/copper text. Sale completion clears its queue before printing, so reporting cannot repeatedly crash every frame. Disabling automatic junk selling through the checkbox or /tb sell cancels pending and active automatic sales; manual Sell listed items remains available.

### Gathering tracking

Mining and Herbalism reminders appear in the existing movable reminder frame when Find Minerals or Find Herbs is inactive. The addon checks the minimap tracking state rather than relying only on buffs. It shows only reminders for professions you have learned. With both professions, it can remind you about whichever tracking is inactive. Enable/disable it with Remind me to enable tracking in /fa. Existing hide-in-combat and hide-while-mounted settings apply. Click its icon to activate the matching tracking spell; the addon does not cast it automatically.

### Account bags, money and item quantities

Open your bags and click the small bag icon beside the left edge of the bag window, or use /fabags or /tb bags. Select a character to inspect its recorded bag slots and stacks. These are read-only snapshots, not access to another character's actual bags. Log into each character once after installing the addon to record its data. Current character snapshots update on bag changes, money changes, world entry and logout. Offline snapshots retain their last observed state and the inventory window displays the timestamp. Bags and reagent bag are included; bank, mail, auction house and equipped item counts are excluded.

Hover over the standard bag money display to see each recorded character's money and their combined account total. Item tooltips list recorded bag quantities per character and a total. Enable/disable the bag button and tooltip additions through Account bags and item counts in /fa. Data cover the WoW account SavedVariables environment where this addon is installed, across recorded realms; currencies cannot necessarily be transferred between those characters.

### Class, riding and profession training

Version 1.4 separated Class spells and Riding tabs; version 1.5 removes both tabs and shows only class-trainer spells. Older rider/profession observations are removed from the class spell cache during migration. Profession trainers no longer add recipes to the class panel. Riding still uses observations from riding trainers; confirmed costs remain observations because trainer pricing is server data.

Opening the native profession window shows a separate Profession Catalogue when enabled. You can also use /tb professions and choose among your learned professions. The bundled reference contains 2,363 non-seasonal records across twelve professions, including recipes, training ranks and abilities. It uses the public Forever client snapshot 1.60.1.69876, dated September 17, 2026, from https://github.com/MAF2414/wow-forever-talents/blob/main/docs/professions-data.json . Only factual names, spell IDs, rank labels, recipe-item flags and skill fields are included; no descriptions or third-party addon code are bundled.

The profession panel now lists only services recorded from that profession’s trainer. Visit the trainer once to populate the list, including unavailable future services exposed by the trainer. Learned recipes are excluded. Unverified client records and vendor/drop/quest recipes are no longer presented as trainer recipes.

### Camera

Camera initialization now sets cameraDistanceMaxZoomFactor to 4 on login, matching /console cameraDistanceMaxZoomFactor 4. Both /tb camera and /tb camera max use 4. /tb camera NUMBER can set an explicit alternative. Accepted values are read back from the client. Disable Apply camera distance on login in /tb to stop automatic initialization.

### Additional validation

The expanded mocked-client integration suite passes with GetCoinTextureString and GetMoneyString completely absent. It checks modern and fallback money formatting, repeated ticks after sale completion, automatic-sale cancellation through both controls, minimap tracking changes, account bag and gold snapshots, tooltip deduplication, class/riding/profession separation, learned-recipe filtering, native profession panel attachment and hiding, and camera limit readback and persistence. This update still requires live-client verification of frame placement and beta-specific APIs.

## Changes in 1.5.0

### Junk and buyback

The junk window is smaller. Prices show the value of each entire stack, with room reserved for the price column. Sorting also uses stack value. Drag or drop an item onto the window, list, or buttons to mark its item type. The dedicated drop box has been removed. Delete lowest stack deletes the whole stack after confirmation, and rejects the operation if that stack changes while the confirmation is open.

Buying back an item stops automatic sales for that vendor visit. Its item type stays protected from automatic sales on that character, including later visits. Explicit manual Sell listed items can still sell it. `/faplay keep clear` clears the bought-back protection list.

### Bag viewer and movement

The small bag icon beside the left edge of the bag window opens the account viewer. It shows icons and stack counts in original bag-slot order, separated by bag, with empty slots preserved. Hover an icon for its item tooltip. This is a read-only view of the character's last recorded bags, not a remotely accessible inventory. Characters must log in again after installing this version to record bag capacities and names; older snapshots cannot reconstruct trailing empty slots.

Standard bags have a Drag bag handle. Move bags outside combat; positions are remembered per character and included in saved interface profiles. Gameplay options include a position reset.

### XP display

Below level 60, the movable XP panel shows current XP percent, remaining percent, rested percent, completed quest reward XP and percent, XP/hour, estimated time to level, session time and XP, played time this level and total played time. Hover to see individual completed quest rewards. Green overlays the part of the current bar covered by completed quests; the displayed percentage is not capped at 100%. The blue overlay indicates rested XP. Unavailable reward data are marked unknown rather than invented. Rewards are estimates before turn-in and may change with level or server bonuses.

XP/hour is the average for the current login session, not a prediction that future activity will maintain that rate. Played time is requested from the server on login. The custom bar replaces the native XP display while enabled; detailed statistics are available on hover. Drag it to place it where you prefer.

### Combat errors and mail

Common range, resource, and cooldown messages are filtered before Blizzard's error display and associated voice/sound handling. Other messages, such as inventory-full errors, remain visible. Toggle this under Gameplay options.

The Send Mail tab gains a Recipients button. Its menu includes other recorded characters on the same realm and previous successful mail recipients, shared across the account. Selecting an address fills the recipient field; sending remains manual. Failed sends are not added.

### Camps

Campfire Nearby (1283391) and Welcoming Campfire (1229739) trigger a notice if Camp Benefits (1229741) is missing. Camp Benefits warns once when its actual remaining duration reaches five minutes. Camp Tent's proximity/rest aura (1229487) triggers a separate tent notice. Boosted Rest (1229451), the cooldown that prevents another tent rested-XP gain, is not mistaken for Camp Benefits.

These notices rely on the client exposing those auras. They do not scan unseen world objects. Spell records were checked against Wowhead's Forever database:
- https://www.wowhead.com/forever/spell=1283391/campfire-nearby
- https://www.wowhead.com/forever/spell=1229739/welcoming-campfire
- https://www.wowhead.com/forever/spell=1229741/camp-benefits
- https://www.wowhead.com/forever/spell=1229487/camp-tent
- https://www.wowhead.com/forever/spell=1229451/boosted-rest

### Rings, crafting, swings, trainer, minimap

`/faplay rings` opens the ring editor. Select a ring in the left list, or enter a new name and click Create named ring. Drag spells from your spellbook and items from your bags into the right area, including onto an existing slice. Right-click a slice to remove it. Changes save automatically. Click Assign key, then press your desired key combination; Esc cancels capture, and Clear key removes a binding. Duplicate drops and keys already assigned to another ring are rejected. Portals and Professions populate automatically with learned supported spells; removed automatic slices can be restored. Ring definitions are shared across the account. Keys open the ring at screen center; click a slice to use it, or click Close in its center. Editing waits until combat ends. This is an original secure radial menu, not the OPie addon.

Create All queues add an estimated total remaining time below the native cast bar, based on measured cast duration and requested craft count. The queue clears on interruption, failure, completion, or an inactive gap. Server delays and variable cast times can change the estimate.

Main-hand, off-hand, and ranged/wand auto-attacks have separate swing bars driven by Forever's PLAYER_SWING events, not guesses from animation or combat-log damage. Drag the panel to move it. Gameplay options adjust width and height. Special attacks that do not emit auto-swing events do not start timers. The native event baseline is documented at https://github.com/Thunderz96/forever-addon-kit .

Train all appears at class and profession trainers. It requests each currently available, affordable service once per run, stopping when the trainer closes or combat starts. Click again to stop. It does not bypass trainer prerequisites or money requirements; the final message counts purchase requests, not an independently confirmed count of learned spells. Use it at a trainer whose offered services you want to purchase.

Right-click the minimap to reveal addon launcher icons in a compact strip to its left. The Trailbound gear is inside the strip, not permanently on the minimap. Original addon click handlers are retained. Native minimap controls remain in place. Disable the feature under Gameplay options to restore other addon launcher positions; /tb still opens Trailbound options.

Open `/fa` or `/faplay` for the feature settings hub. Each feature has a separate page; opening a page hides the hub, and Back returns to it. All new feature toggles and XP/swing/bag positions are part of named interface profile snapshots. Ring definitions and recipient history are shared account data.

### Validation and sources

All Lua files pass syntax checks. The expanded mocked-client regression suite covers full startup, old features, stack-value ordering and whole-stack deletion, stale identity/count checks, buyback protection across vendor visits, bag capacities and icon-grid slots, completed quest XP above 100%, mail-history deduplication, craft estimates and interruption, trainer affordability and repeated-purchase prevention, resource error filtering and its toggle, swing events, ring UI construction, and camp warning throttling.

No unrelated businesses or gym websites are used as addon data sources. Blizzard UI source mirrors, the Forever-specific captured API baseline, Forever client data, and Wowhead's Forever records are used. This build has not been tested inside a live Forever client; secure ring execution and native frame placement still require in-game verification.

### Buff reminder options and blessing logic

Buff reminders now have a separate window opened with Buff reminders in /fa. It contains reminder toggles, hiding rules, icon/text sizes, movement, position reset and gathering reminders. Mage Frost Armor, Ice Armor and Mage Armor are alternatives: any active rank satisfies the armor group.

Paladin reminders distinguish blessings cast by the player from blessings supplied by another paladin. Own blessings satisfy the reminder unless a higher known rank is available. Without an own blessing, a weaker foreign blessing can be upgraded; an equal/stronger one is complemented with another known blessing. Auto preference uses the talent tree with the most points when that API is available: Holy favors Wisdom, Protection favors Sanctuary/Kings, Retribution favors Might. Blessing selection is always automatic; a character without talent data favors Might. If all useful known alternatives are already covered at equal or higher rank, no conflicting reminder is shown.

Additional regression checks pass for trainer-only filtering including triggered and talent-dependent ranks, separate reminder controls, paladin caster/rank comparisons and role preferences, and both Ice Armor and Mage Armor satisfying an existing Frost Armor reminder.


## Changes in 1.6.0

- Swing bars update every rendered frame. Gameplay options provide Unlock / lock swing position, a draggable preview, width/height controls, and Reset swing. Forever’s native swing bars are hidden while the custom timer is enabled and restored when disabled.
- The XP display is a thin framed bar with the normal status-bar texture and 20 segment divisions. Current/max XP, current percent and completed-quest XP/percent appear on the bar. Needed XP, XP/hour and estimated time to level remain visible directly below it. Hover for rested XP, session/played time and each completed quest reward. Native experience bars are removed through the tracking manager’s XP selection; reputation and other tracking bars remain available. Disabling the custom display restores native XP.
- The account-bag icon sits just outside the bag window’s left edge with a tooltip. It uses an independent parent to avoid the bag frame clipping it, and follows the bag’s show/hide state. /fabags remains available.
- Create All’s cast-bar estimate is 24 pixels below the bar with outlined text. A second estimate appears below the profession Create All button, using selected recipe, craftable quantity and cast duration. If cast duration is not exposed before the first craft, the preview states that explicitly; observed durations are remembered per character for later estimates.
- Class and profession rows include ability icons. The profession panel follows the currently open profession, has no profession-selection buttons, sits 65 pixels to the right of the native frame, and includes only trainer-confirmed services. The catalogue-opening button was removed from options.
- Camera factor 4 is applied to existing characters once during migration; later explicit settings remain editable.
- The minimap menu is a pop-out icon strip on the left. It includes the Trailbound gear and keeps original addon click handlers, mouse input and visible icon scaling.
- Speedy auto-loot requests unlocked loot immediately on LOOT_READY, without the native pickup delay. It closes the loot immediately after the last confirmed slot clears. It respects the normal auto-loot modifier, skips master-loot handling and locked slots, and does not force binding confirmations. Outstanding loot/full bags keep the window open. It cannot accelerate server response time. Toggle Speedy auto-loot and instant window close in /faplay.

Validation: all Lua files pass syntax checks. Focused mocked-client checks pass for factor 4, native XP suppression/restoration without hiding reputation, compact XP with preserved details, unclipped bag-button visibility, confirmed profession filtering, original minimap click handlers and the gear’s placement, swing values changing between individual frames, swing preview controls, crafting estimates and placement, auto-loot modifier inversion/locked slots/master loot, duplicate request prevention, and immediate closure only after the last confirmed loot slot. Live-client placement still needs in-game verification.

## Important short buff tracker

Open /fabuffs, or choose Important buff tracker in /fa. Enabled by default, it displays helpful effects on your character with a full duration of 1–30 seconds, whether cast by you or another player. Icons show their actual spell texture, cooldown swipe, remaining seconds and stack count. They sort by expiry, with red countdowns during the last five seconds. Hover for the buff tooltip and caster.

Automatic categories cover immunity and freedom, damage reduction and shields, movement speed, and damage, haste or stat boosts. Short potion effects include Swiftness, Free Action, Limited Invulnerability and Living Free Action. Instant effects without a lasting buff are not displayed. Long buffs do not become eligible merely because their remaining time drops below 30 seconds.

The dedicated options window lets you toggle categories and caster sources, enable combat-only display, edit minimum/maximum duration, icon size and columns, and show names. Press Enter to apply numeric fields. Unlock position to drag the tracker; closing its options locks it again. Reset position restores its default location near the center of the screen. These settings and spell overrides are included in named account profiles.

Enter a spell ID to include an otherwise unrecognized effect, exclude a spell, or clear its override. Displayed icons never change spell rules when clicked; edit exclusions in options. Custom inclusions still obey duration, caster and potion filters. Automatic classification uses effect IDs from the Forever client reference at https://github.com/MAF2414/wow-forever-talents (1.60.1.69876); live helpful aura data supplies duration, caster, texture and countdown. New custom effects may need a manual inclusion.

## 1.8.0 fixes and editing

The secure ring click wrapper now supplies a valid empty pre-handler instead of nil. Trainer observations without rank text merge into matching reference spells before learned-spell filtering; ambiguous observations of ranked names are omitted. Learned spell IDs and known higher ranks remove already learned and obsolete ranks. Spell rows show the ability and rank, with a separate Level N line and actual icon.

Settings are split into quests/interactions, junk, reminders, important buffs, mana, training, XP, swings, rings, combat messages, account bags, bag movement, minimap, looting, camps, camera and profiles. Opening a feature hides the settings hub. The swing page automatically unlocks and previews all three bars, including when the timer is disabled, and locks them on close. Width, height and reset controls apply directly to the preview.

Common combat errors are filtered from both the interface text and the normal error handler. The filter supports both legacy text-only and modern ID-plus-text events, as well as direct recognized messages. Unrelated errors remain visible; turning the option off restores normal messages.

Validation: all Lua files pass syntax checks. Mocked-client checks cover trainer deduplication and known/higher-rank filtering; visible XP numbers and ETA; automatic swing previews; secure handler string validation; drag/drop, duplicate rejection, individual slice removal and modifier key capture; modern, legacy and direct error filtering/restoration; and the previous camera, bags, professions, minimap, crafts, loot and short-buff behavior. Live-client rendering, secure actions in combat and real keybindings still need in-game verification.

The important-buff options window can be dragged out of the way. Browse tracked spell rules opens a separate movable, searchable catalogue with icons, spell IDs, categories and per-spell inclusion/exclusion. It shows configured rules; duration and helpful-aura filters still decide which effects appear in the live tracker. Stealth, Prowl, Shadowmeld and temporary Vanish stealth effects have a dedicated toggle. Untimed stealth auras are the deliberate exception to the normal duration filter. Expired real buffs are removed even while positioning the tracker; preview icons are separate from live buffs.

Additional checks pass for untimed stealth and its toggle, expiration while unlocked, the buff catalogue, and actual main-module startup/navigation. The options hub hides the previous editor, and returning from swing editing ends its preview.

## 1.8.3 fixes

The minimap right-click strip has no background or border. Original icon buttons remain clickable, with full alpha and enabled state. Camera commands and login only increase cameraDistanceMaxZoomFactor; they never call CameraZoomOut or change your current zoom distance.

Important buffs now use a selected list of major active cooldowns, immunity/freedom effects, shields and speed boosts. Curses, fears, forms and passive stat/talent records were removed from the automatic catalogue. Helpful-aura filtering is reinforced by explicit harmful-aura and passive-spell rejection, including for manual inclusions. Active talent-granted cooldowns such as Power Infusion and Death Wish remain eligible because they are important temporary buffs. The live Elemental Blessing / Skysight buff name supplies the new racial speed rule; its actual ID is recorded when observed rather than guessed. It obeys the normal duration filter, so long versions remain hidden. Blizzard's racial announcement identifies Skysight and Elemental Blessing: https://worldofwarcraft.blizzard.com/it-it/news/24304075/crea-leroe-che-desideri-essere-in-world-of-warcraft-forever .

Bag snapshots support modern and legacy APIs, preserve previous contents while bag data are unavailable during loading, and refresh on bag changes and opening the bag. Character snapshots provide a recovery copy of account records. Gold and bag totals use all recorded characters. Log into each character with the addon enabled and log out normally to save its information; an addon cannot inspect characters that have never been recorded.

Drag bag appears above the bag header and remains clickable. Position restoration handles separate bag frames when the combined frame does not exist; drag-and-drop of items is unaffected. Reset bag positions invokes native anchoring again. Positions persist per character and in interface profiles.

The ring wrapper passes an explicit string pre-handler. The error showing preBody=nil at ForeverAssistPlay.lua:369 is from an older file. Close WoW and replace the entire ForeverAssist addon folder with this package, keeping your WTF SavedVariables files. On login, chat reports 1.8.4; /tb version also checks gameplay, buff-rule and bag-module versions so mixed or stale files can be identified.

Validation: Lua syntax checks and the previous regression checks pass. Added checks cover cross-character gold/bag/item totals, legacy bag APIs, preservation during loading, snapshot recovery, movement without a combined bag frame, exposed drag handles, camera range without forced zoom, curated rules and harmful/passive rejection, live racial-name recognition and duration filtering, valid secure-wrapper strings, and the background-free minimap strip. Live rendering and secure in-combat ring actions still require in-game verification.

## Restricted aura access fix (1.8.3)

Aura reads now share a restriction-aware accessor across short buffs, class/gathering reminders and camp notices. It checks the client secrecy predicates before enumeration, catches unexpected refusals, backs off after a refusal and rejects secret aura fields. Unavailable data are kept distinct from an empty buff list, avoiding false missing-buff reminders. The short tracker hides unavailable live auras and checks for restored access once per second.

Your own Berserking has an optional ten-second estimate from a readable successful-cast event. This appears during restricted combat without reading secret aura data. Actual aura data replace the estimate when available. The tooltip labels it as an estimate because dispels or early removal cannot be observed while aura access is restricted. Disable Estimate my Berserking in combat in /fabuffs if desired. Other restricted buffs cannot be identified by this tracker until the client permits aura reads.

Tests pass for zero enumeration calls while secrecy predicates deny access, caught unexpected refusals and retry backoff, recovery after access returns, and immediate own-Berserking fallback with timely expiry, alongside the existing regression suite. Live-client testing remains required.

## Camp, gold and minimap update (1.8.3)

The ranged swing bar is labeled Ranged, including when a wand is equipped.

Near a campfire, a small Sit at campfire button appears below the center of the screen. Clicking it executes /sit through a secure action button. It hides in combat and while Welcoming Campfire is active. The actual Welcoming Campfire aura displays its icon and remaining time near the center of the screen; the timer updates each frame and disappears on expiration or removal. Untimed versions show Active until removed. This uses Campfire Nearby (1283391) and Welcoming Campfire (1229739), with the live welcoming aura name as a fallback. Camp notices, Sit button and welcome timer are controlled together in /tb → Camp notices.

Account gold is now explicitly visible below the native bag and in the saved-bag window. Hover either account total for each recorded character's gold and the combined total. Native money hover hooks now also attach to coin buttons created after the money frame, fixing the early-installation gap. The saved-bag window has a clean dark background, character cards with names/realm/gold, an account-total header and a separate bag-grid section. Bag layout and slot order remain unchanged.

The minimap is square by default. /tb → Minimap buttons → Use a square minimap restores the round mask when disabled. The square mask has a thin border; recorded circular decorations are hidden while square mode is enabled and restored afterward. Addon launchers receive the SQUARE shape hint, and right-click icon behavior is preserved.

Tests pass for the Sit macro configuration, camp proximity and leaving-camp cleanup, welcoming countdown and expiration, camp option toggles, late-created coin tooltip hooks, bag/account gold visibility and per-character totals, saved-bag UI construction, square/round mask restoration, and the Ranged label. All Lua syntax checks and previous regression checks also pass. Live rendering and the secure Sit click still require in-game verification.

## Changes in 1.8.4
- No-target and invalid-target combat errors are filtered before Blizzard plays their error sound (Combat messages option).
- Combat & recovery settings enable central countdowns and a six-second Well Fed ready notice.
- Bags & vendors → Assign junk keybind assigns or clears the key that opens /junk.
- Account gold is saved independently of bag contents and appears above the bag at the top right. Hover to see each character's saved balance. Log characters in to refresh their balances.
- Cross-character item tooltips omit Hearthstone, Mining Pick, Skinning Knife, and Blacksmith Hammer; their bag slots remain visible.

## Changes in 1.8.5
- Cannibalize joins the food/drink display, using the actual channel end and stopping on interruption.
- Class/gathering reminders are now named Buff reminders. Paladin blessings always use automatic talent, rank and existing-buff detection; old manual preferences are ignored.
- Settings now have a dark panel with a highlighted sidebar, four grouped preference categories and dedicated editor/profile entries. Small settings stay on the same page, while complex editors retain their previews and controls.
- Categories: Questing & training; Bags & vendors; Combat & recovery; Map & camera.
- Editors: Buff reminders, Important buff tracker, Experience bar, Swing timer editor, Ring editor, Account profiles.

## Changes in 1.8.7
- Gold totals use the live current-character balance again. Saved balances update every two seconds independently of bags; brief startup zeros do not erase an existing positive balance. A real money event can still record a legitimate zero.
- `/tb gold` prints live copper, all saved character balances, account total and whether account bag display is enabled. This distinguishes a live API/recording problem from a display problem. The reported in-game failure has not been reproduced locally; send this output if gold is still wrong.
- Questing & training and Bags & vendors explain the Shift bypass for NPC gossip, automatic quest actions and vendor sales.
- Default is created automatically and replaces the old migration label Imported settings. It shares addon settings across characters and saves/restores exposed interface settings at logout/login. Named profiles remain snapshots. Delete selected asks for a second click; deleting an active named profile returns the character to Default. The built-in Default cannot be deleted.
- Editors and profiles keep the main settings open and dock on its right. Opening another editor closes the previous one. The pair scales down when needed to fit the screen; closing the editor restores the main panel position/scale. Closing main settings closes its editor.
- Important short buffs and Account profiles now have Back to settings buttons.


## 1.8.7 — Jemai

Created by Jemai. Settings includes a bundled 128×128 profile portrait (48 KiB); no online images or extra libraries are loaded.

Bandage channels and helpful First Aid effects now appear alongside food, drink and Cannibalize, with interruption and expiry handling. Recently Bandaged is a debuff and is not tracked. Buff-icon clicks no longer exclude spells: use the spell-rule options.

Map & camera includes Hide stance / shapeshift bar. Protected visibility changes wait until combat ends; stance abilities and keybindings remain available. Editors share dark styling and a bottom-left Back to settings button.

## 1.8.8 — Miami Beach & native damage meter

Settings and editors now use warm sand panels, seafoam navigation, coral buttons and teal headers with sunset accents. Jemai's portrait remains bundled locally. The skin uses game fonts and solid-color textures: no new media downloads or libraries.

Open /tb and choose Damage meter, or use /tb meter. This reskins Blizzard's native damage meter, including spell-breakdown rows, rather than collecting or recalculating damage. Native categories, values, sessions and click actions remain intact. Other addons' damage meters are not modified.

The editor controls width, height, window scale, row height, text scale, background opacity, Seafoam/Coral/Sunset bar colors and optional native class colors. The sample preview is explicitly labelled PREVIEW and does not feed fictional data into the native meter. Drag that preview to position the primary meter; pink handles above live meter windows allow individual positioning while the editor is open. Closing the editor hides the preview and handles. Reset restores the skin's default dimensions and the native meter's original position. Disabling Reskin restores the captured native styling and dimensions.

Saved meter options participate in account profiles. Layout changes requested in combat wait until combat ends. Cosmetic callbacks never query C_DamageMeter, aura APIs or combat data providers. If the native UI is loaded later, the settings are applied when it appears. Native meter availability remains controlled by the game.

All Lua files passed syntax checks; mocked-native-frame checks cover colors, sizes, class colors, late-created rows, combat deferral, restoration, editor/preview navigation and profile replacement. In-game layout and taint behavior still require verification on the actual Forever client.

## 1.8.9 — Bank browser

Open bags and click the Bank icon beneath the account-bags icon, or use /fabank or /tb bank. Choose a character using the native dropdown, then choose a saved bank tab at the right. The browser keeps the normal Blizzard bank frame appearance, slot artwork, seven-row column layout, item icons, empty slots and stack counts. The actual banker window and its deposit/withdrawal behavior are unchanged.

Each character must visit a bank once with this version enabled to record its contents. Snapshots update while the bank is open; complete reads replace older contents, while unavailable or failed reads preserve the last complete snapshot. The saved timestamp is shown. Other characters and remote views are read-only: they cannot withdraw, deposit, move or use stored items. Characters without a snapshot show an explicit Bank not recorded message.

Character bank tabs are supported on Forever's modern API, with a fallback for older bank/bank-bag APIs. Guild banks and shared account-bank tabs are not included in this character-bank browser. Bank snapshots are kept separate from carried-bag counts and gold, and have a per-character recovery copy. Keep SavedVariables when updating.

Lua syntax and simulated checks passed for stack snapshots, tab layouts, character switching, read-only slots, failed-read preservation, real withdrawals, cross-character isolation and older bank APIs. Actual in-game appearance still needs verification.


## Changes in 1.8.12

- Vendor sale polling and automatic startup wait are reduced to 50 ms. Actual throughput depends on the server confirming bag changes; stalled requests retain the existing timeout. Combat, cursor, repair mode, vendor-close, bought-back item protection and uncached-price checks remain in place.
- Plainsrunning uses the active stacking buff ID 1299038, independently of passive racial spell 1259918. It respects Movement speed, caster and spell exclusion settings, and supports untimed auras. Stack count updates follow normal aura refreshes. The numeric buff ID was checked against https://github.com/Hey0001/Taurun/blob/main/Taurun.lua ; no addon code or audio was copied.
- The new icon is used by the ForeverAssist options launcher and the TOC IconTexture metadata for the native AddOns list. The original generated prompt: “A bold antique gold infinity loop integrated with a simple four-point compass medallion on dark teal, classic fantasy game icon style, readable at 30 pixels, no letters, gear or portrait.” Generated using the built-in image-generation tool and exported to Media/ForeverAssistIcon.tga.


## Changes in 1.8.13

- Complete bag snapshots are committed atomically, with loading failures preserving the prior contents. Independent backups restore missing primary records and retain other characters when changing profiles or upgrading. A temporary missing GUID no longer moves a saved GUID record to a temporary name key. Money recording remains independent of bag reads.
- Bag and bank viewers share the native portrait-frame skin, saved-slot textures and character dropdown. Previous/Next bank buttons are gone; both viewers have a confirmed Forget character action that also removes the recovery backup.
- Profiles restore an explicit allowlist of native interface preferences and one complete action-bar visibility mask. This uses the game's APIs rather than editing native frames or executing native SettingsPanel commit callbacks. The native action-bar API usage was checked against Blizzard's shipped source mirror at https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/ActionBars.lua ; party CVar names against Mainline/InterfaceOverrides.lua on the same Forever branch.
- Mocked-client integration checks cover offline record retention and recovery, failed reads and real removals, zero/loading guards, confirmed forgetting from both menus, seven action-bar toggles, Default login/logout, named profiles, and absence of native Edit Mode/SettingsPanel calls. In-game visuals and taint behavior still require client verification.


## Changes in 1.8.14

- Reduced background camp/recovery aura polling from 5 Hz to 1 Hz, while preserving aura and channel event refreshes. Recovery text uses a 10 Hz timer instead of per-frame rebuilding; swing rendering is capped at 20 Hz and important-buff text at 10 Hz.
- Cached Paladin spell/rank lookups until the spellbook changes. Unchanged gold checks reuse saved records; successful bag reads no longer first copy the old bag snapshot. Independent recovery backups remain intact.
- Moved the account-bag character selector below/right of the portrait. Small bags use a narrower, shorter window; larger inventories grow within screen height and scroll when necessary.
- Added Combat & recovery > Move recovery timer. Choose Unlock and preview timer, drag the preview, then lock it or close the editor. Includes reset position; position is included in addon profiles.
- XP bar shows estimated mobs to level from up to 20 kill-XP messages within the last ten minutes at your current level. Quest and exploration XP do not become samples. Rested/group rewards are reflected in the reported kill XP; changes to enemies or bonuses take more samples to settle. Unsupported/restricted kill messages leave the estimate pending. Hover the XP bar for average XP and sample count.

Memory rising and falling is consistent with automatic Lua garbage collection, and alone does not measure CPU use. This update does not force garbage collections. Real client memory, CPU, frame rate, localized XP messages, and window placement still need in-game verification.

Install with WoW closed by replacing Interface/AddOns/ForeverAssist. Keep WTF and SavedVariables to retain character snapshots and profiles. Run /tb version to verify all reported versions are 1.8.14.


## Changes in 1.8.15

- Buff reminder icons use a compact 12px gap with abbreviated, width-limited labels (at most 12px font). Hover shows the full reminder. Reminder icons support dragging in unlock mode. All reminder icons hide in capital cities; the editor preview remains available.
- Added separately toggleable missing hunter/warlock pet reminders under Buff reminders. Hunter needs both Call Pet and Tame Beast; warlock needs a learned permanent-demon summon. Active pets and petless builds suppress the prompt. Recognizes Lone Wolf and Demonic Sacrifice; Demonic Pact allows pet reminders alongside sacrifice. Talent and spell checks are cached and invalidated on relevant game events.
- Added Cozy Sleeping Bag reminders when Well-Rested is missing or under five minutes, provided item 211527 is carried in bags, ready to use, and the player is outdoors outside instances, capitals and rested areas. Reads the actual bag-slot cooldown.
- A fresh Well-Rested (429959) update to at least three stacks and approximately 120 minutes triggers a three-second central confirmation. Existing buffs at login do not trigger it. Reminder and confirmation can be disabled together under Buff reminders. Restricted/unavailable aura reads do not generate reminders or estimated buff states.

Lua 5.1 syntax and simulated regression tests passed for existing bags/banks/gold/profiles plus reminder layout, spell/talent gates, capital detection, sleeping-bag conditions and notification transitions. Live-client visual placement, class talent IDs and restricted-combat behavior still need verification.


## Changes in 1.8.16

- Saved account bags now use one continuous combined grid, with empty slots and stack counts intact. Removed individual bag names, headings and gaps. Window size follows combined capacity.
- Saved bank character selection uses the account-bag header placement to clear the portrait. Storage cells, bank tabs and saved information are spaced below it.
- Added Inner Focus (14751) under important offensive buffs, including its active-until-consumed untimed aura. Supports the existing self-cast fallback when the cast event is readable.
- Restricted or incomplete aura scans preserve the last confirmed tracked buffs instead of clearing the window. Timed buffs still expire at their last confirmed expiration. Readable incremental removal events clear cached buffs immediately. Buff text has a question mark when its state is uncertain; tooltips explain that early removal may be hidden. Live aura reads reconcile the state as soon as access resumes. Untimed effects cannot be confirmed as consumed when both aura access and removal events are restricted.
- Restyled the secure campfire Sit button with a campfire icon, dark panel, warm border/text and hover feedback. Its macro remains /sit, and protected visibility remains controlled out of combat.
- Vendor sale reports list each confirmed item and aggregate its actual quantity and proceeds, followed by total proceeds. Repeated stacks of the same item are combined into one line.

Lua 5.1 syntax and simulated checks passed for combined bag layout, bank-header placement, Inner Focus and user filters, unavailable/partial combat reads, timed expiry, readable removal events, cast-to-aura reconciliation, itemized vendor reporting and the secure Sit action. Live-client appearance and combat restrictions still need verification.


## Changes in 1.8.17

- Added cast-based Power Word: Shield estimates for all bundled ranks. A readable UNIT_SPELLCAST_SENT target matching your character is required, followed by a successful cast. Shielding someone else does not create a self-shield timer. Recasting replaces old shield ranks and restarts the estimate.
- Inner Focus now clears from cached/estimated combat displays after a readable successful consuming priest spell. The bundled priest spell catalogue is used; free Desperate Prayer is excluded. Casting Inner Focus again resets its state.
- Readable incremental UNIT_AURA added/removed data updates the tracker even when enumeration is unavailable. Secret fields and secret tables are rejected before comparison. Confirmed aura data replaces cast estimates. Question marks identify estimates or unavailable live confirmation. When cast targets/events and removal data are restricted, new applications and early shield absorption/removal cannot be verified.
- Replaced the expanding strip of moved minimap icons with a compact dark six-column, four-row paged launcher grid. Source icons retain their original parent, position, scale, color and scripts. Proxy clicks invoke original handlers with the actual mouse button.
- Removed repeated five-second minimap discovery/layout work and the full-menu OnShow layout hooks. Discovery occurs during setup/opening. Launcher frames are reused across option toggles. Hidden icons, protected controls and icons reparented into another collector are skipped. Disabling the menu restores original icon visibility. Existing minimap mouse handlers are hooked rather than replaced. Another addon independently opening a right-click menu may still require disabling one of the two menu features.

Lua 5.1 syntax and simulated regression checks pass, including self-shield reapplication and other-target exclusion, Inner Focus consumption, secret-safe incremental aura payloads, 55-launcher paging, source geometry preservation, click forwarding, no closed-menu background scans and restoration. Actual combat event visibility, shield consumption, minimap placement and other-addon compatibility still need in-game testing.


## Changes in 1.8.18

- Suspended restoration of all captured native interface preferences from account profiles, including login through Default. The addon no longer replays party/raid CVars or calls SetActionBarToggles through profiles. Existing native preference snapshots are retained, including when saving or logging out, rather than discarded. Profiles continue applying ForeverAssist settings. The profile window explains that native UI restoration is paused.
- Removed the status-tracking manager method replacement, UpdateBarsShown calls and native experience-bar hide hooks. The custom experience bar continues rendering independently; the native XP bar may remain visible. Manage Blizzard's native bar through the game's own UI.

These changes remove two plausible taint entry points related to native UI settings/layout. The CompactUnitFrame secret-health error cannot be reproduced or confirmed fixed without a live client. Syntax and simulated regression checks passed, including zero native preference writes across profile actions, saved snapshot preservation, existing addon features, and real custom-XP rendering with native managers that reject modification.

Completely close WoW, replace the entire ForeverAssist folder, and restart before testing. Retain WTF/SavedVariables. A full restart gives the new version a clean taint state; replacing files during a session cannot remove existing taint. Verify /tb version reports 1.8.18.

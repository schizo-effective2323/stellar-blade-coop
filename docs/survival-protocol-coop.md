# Survival Protocol Co-op — Feasibility Plan

This is a design plan, not an implementation. It asks how [Survival Protocol](https://www.nexusmods.com/stellarblade/mods/4009) (SP 0.1.4-beta: title-screen roguelike, 20 waves, one life, six difficulties) could become playable for two players, and what of Stellar Blade Online (this repository) already covers the hard parts.

Related reading in this repo: [Night Operation](night-operation.md) (wave co-op already built), [How it works](how-it-works.md) (Steam link, shared enemies, night line), [README credits](../README.md#credits) (SP code already adapted into Night Operation).

## Verdict

Co-op Survival Protocol is possible, but not by running two independent Boss Challenge sessions and hoping they stay in sync. The workable shape is **host-authoritative run state over Stellar Blade Online's Steam link**, with each PC still simulating its own arena copy, the same pattern Night Operation already uses.

The main fork in the road is whether SP keeps riding the game's Boss Challenge mode, or whether co-op waves are rebuilt on Night Operation's custom spawn path. That choice decides almost everything else.

## Locked decisions (from design)

These are decided for the first co-op cut:

1. **Host starts the run.** Only the linked host can begin a co-op SP run from the SP menu. The guest cannot start one.
2. **Transfer together.** The host initiates while both are linked (typically still on the title / SP menu). Once the guest accepts, **both clients load the chosen difficulty's arena together**, then share GET READY and wave 1. Neither player is already fighting when the other arrives.
3. **Personal rewards on a shared success.** If the run succeeds, **each** player unlocks whatever reward **their own** SP progress is currently eligible for on that difficulty (colourway, accessory, music, next-tier unlock — whatever solo SP would have granted them for that clear). The host's progress does not overwrite the guest's, and vice versa. A player who already earned that clear's reward gets nothing new; a player earlier on the track still advances. Failures unlock nothing on either PC.
4. **Partner revive.** A downed EVE waits for her partner (Night Operation-style interact hold). No self-revive in v1. The run fails when both are down with no revive under way (`failed:both`). A Hardcore one-life mode can wait for a later cut.
5. **NIKKE DLC required (for now).** Co-op SP is only offered when **both** players own the Goddess of Victory: NIKKE collaboration DLC. Solo SP is unchanged. The Co-op run row stays hidden or refused with a clear reason if either side lacks NIKKE — including difficulties that solo SP allows without it. This keeps one support matrix (Scarlet / Omega assets available on both PCs) for the first co-op beta; a non-NIKKE co-op path can open later.
6. **Always check against Ghidra.** For compatibility and stability, every co-op SP change that touches game behaviour (Boss Challenge start/transfer, wave/boss phase, spawn pairing, revive/respawn, hazard actors, DLC gates, rewards) must be verified against the pinned-build Ghidra DB of `SB-Win64-Shipping.exe` before it is treated as done. Do not invent offsets, call sites, or net-mode assumptions from Lua alone. Match Online's existing practice: name the `FUN_*` / globals used, confirm they still match the supported Steam build, and refuse or feature-gate when the image disagrees.
7. **Shared UE4SS 1.3 stack.** Co-op SP targets the same UE4SS as Stellar Blade Online: **Stellar Blade UE4SS 1.3** (Nexus 2952, Git SHA `08a0733`). Pin **Survival Protocol 0.1.5-beta** (main lua391 on branch `sp-ue4ss13-port` in `schizo-effective2323/schizo-effective-mods`). Co-op bridging assumes that build co-loaded with Online — do not plan a dual-UE4SS or “port Online onto 148” path.

## What Survival Protocol is today

SP is a solo title-screen mode that wraps the game's Boss Challenge arenas:

| Piece | Solo SP behaviour |
| --- | --- |
| Entry | Title menu row → difficulty pick → load a Boss Challenge arena |
| Run length | 20 waves; sub-boss at 10; final boss at 20 |
| Lives | One life; death ends the run |
| Difficulty tiers | Six arenas (E-04 through Scarlet / NIKKE for Omega) |
| Escalation | Colour-tiered enemy rosters, 50 modifiers (two per run), 25 hazards |
| Presentation | Own menu, announcer, music helper, loading screens, boss darkening |
| Progress | Separate from story saves; CNS outfits and music unlocks |
| Engine seat | Boss Challenge HARD tab; wave counter follows the game's challenge waves |
| Stack | Stellar Blade UE4SS 1.3 (Nexus 2952; also still runs #148); installs as `ue4ss/Mods/RoguelikeMode` + `RoguelikeMode_P` pak; CNS for outfits; NIKKE for Omega |

Stellar Blade Online already borrowed SP's combat helpers (aggro wake, AI adopt, stuck teleport, spawn spread, death-screen watch, body validity). Night Operation and `coop challenge` are **not** SP. They are a shorter custom-spawn survival mode for two Steam-linked players, with SP-shaped challenge names and some of the same Lua ideas.

## What co-op already exists here

Useful building blocks, already in-tree:

| System | Role for SP co-op |
| --- | --- |
| Steam lobby + protocol 14 | Two-PC session, version gate, chat, partner ghost |
| Partner ghost / vit lines | See and track the other EVE in the arena |
| Shared enemies + same place | One HP bar / death per paired monster across both worlds |
| Shared bosses (channel 2) | Host-driven boss phase / arena event hints for Alpha bosses |
| Night line (`h` / `g`) | Host-authoritative wave phase, score, masks, down/revive |
| Night Operation co-op run | Join checks, countdown, shared score, partner death rules |
| Friend revive | Interact-hold revive; SP co-op reuses this (partner revive, no self-revive) |
| CNS outfit ghost | Partner's SP unlocks can show if both have the CNS packs |
| Co-op saves | Isolate experiment from story progress |

Gaps relative to SP:

- Night line masks cover **5 waves × 8 slots**. SP needs **20 waves**, bosses, modifiers, hazards, and a longer phase vocabulary.
- Only the Shooting Range challenge is marked `coop=true` today; swarm / skulls / gauntlet stay solo.
- Steam link is **two players**. SP's fantasy can stay at two for a first co-op cut.
- SP tip on GitHub is **0.1.5-beta / lua391** (`sp-ue4ss13-port`); co-load smoke + bridge coding are the remaining gates (main-PC active test already ran with StellarCoop loaded).
- Boss Challenge itself has **no multiplayer replication**. The game never ships a dual-client challenge run.

## Architecture options

### A — Bridge SP through Stellar Blade Online (recommended first cut)

Keep SP's identity (title entry, difficulties, modifiers, hazards, rewards). When a Steam session is up, SP hands **run authority** to a co-op layer that speaks the existing night-style wire (or a sibling `sp` line on channel 0).

```
  both on title / SP menu, Steam-linked
           |
  host picks difficulty → Co-op run
           |
  guest gets ask → accepts (or refuses: busy, restart-required, …)
  (Co-op run only offered when both own NIKKE)
           |
  both transfer into the same Boss Challenge arena together
           |
           +-- host: rolls modifiers/hazard, owns wave/boss phase
           |         encodes SP state on the link
           +-- guest: mirrors phase, fights local copies,
                     reports kills / death
           |
  shared GET READY → wave 1
           |
  on success: each PC grants that player's next eligible reward
```

**Pros:** Reuses SBO's hardest infrastructure; SP stays the product the player opens; outfit/music progress can stay in SP's files.  
**Cons:** Still fights Boss Challenge's single-player guts; guest must suppress SP's autonomous wave kicks; second-run arena crashes become a two-PC problem; EventSpawnId is 0 on Hard so pairing cannot use spawn keys.

### B — Rebuild SP waves on Night Operation's spawn path

Stop depending on Boss Challenge wave managers for co-op. Host and guest spawn the same roster from definitions (as `nightop/waves.lua` does), keep SP's arenas only as maps / set dressing, and re-implement boss arrivals as custom or shared-boss fights.

**Pros:** Clean host authority; wave masks and pairing already match the co-op model; easier automated tests in this repo.  
**Cons:** Large rewrite of SP's core loop; boss pools, gate FX, wave-counter fidelity, and "feels like Boss Challenge" presentation must be recreated; solo SP and co-op SP could diverge.

### C — Standalone SP co-op (port the link into RoguelikeMode)

Copy or depend on StellarCoop's native Steam worker inside the SP mod folder, with no Night Operation product surface.

**Pros:** One mod for SP players who do not want Online's other features.  
**Cons:** Duplicates protocol, lobby, ghost, and fight sync; two places to fix Steam/build breakage; GPL boundary and packaging work.

### Recommendation

Ship co-op as **Option A with a measured Option B escape hatch**:

1. Prove two players can enter the same arena, see each other, and survive early waves under host authority while still using Boss Challenge spawns (A).
2. If Boss Challenge desync, reused bodies, or boss arrival prove unfixable for two clients, move wave ownership onto custom spawns (B) without abandoning the SP menu and rewards.

Do not start with C. The link stack is the expensive part and already lives here.

## Design decisions to lock before code

These are product choices, not implementation details. Co-op feel collapses if they stay implicit.

### 1. Lives — locked

**Partner revive** for v1: a dead EVE is down; her partner revives her with the interact hold (reuse Night Operation's revive UX). No self-revive. Fail when both are down with no revive under way (`failed:both`). Classic one-life Hardcore is deferred.

### 2. Who rolls the run

Host rolls difficulty (already chosen), the two modifiers, and the hazard once at ask-time. Guest receives them on the wire and applies local-only presentation (announcer lines, HUD). World-affecting hazards must be applied on **both** clients from the same seed/ids, never rolled twice.

### 3. Score and rewards — locked

- **Score:** host-authoritative, same as Night Operation (a kill counts once across worlds when shared enemies are on).
- **Unlocks (locked):** on a shared success, each client runs SP's normal eligibility check against **its own** progress file and grants that player's next reward for the difficulty just cleared. Examples: host might unlock the accessory version while guest unlocks their first colourway of the same suit; a player who already has everything for that clear sees no new unlock. Progress files never travel over the link. Failures unlock nothing.
- **Best runs:** local `records`-style files; no cross-PC leaderboard in v1.

### 4. Start flow — locked

1. Both players are Steam-linked (friends session as today) and **both own the NIKKE DLC**. They are still on the title screen / SP menu — not already in an arena.
2. Host opens SP. **Co-op run** is only available when the link reports NIKKE on both sides; otherwise the row is hidden or refused (`NIKKE DLC required for co-op`). Guest cannot start.
3. Host picks a difficulty and chooses **Co-op run**. Guest receives an ask (accept / refuse). Refuse reasons include: not ready, restart-required state, already in a run, NIKKE check failed on their side.
4. On accept, **both** clients transfer into that difficulty's arena together. The run does not spawn wave 1 on the host while the guest is still loading.
5. When both report arena-ready on the `sp` line, shared GET READY, then wave 1.
6. Solo SP is unchanged (including non-NIKKE solo play when no co-op session is up).

Transfer failure on either side aborts the shared run before wave 1 (clear notice on both screens). Same if one client hits SP's second-run / restart-required softlock.

### 5. Distance and camera

Arenas are compact enough that ghost + shared enemies matter more than long-range travel. Because both transfer in together, the old "guest not in arena yet" case is a **pre-wave abort**, not a mid-fight refuse. A mid-run softlock on either client still aborts both with a clear "restart required" outcome.

## Technical blockers mapped to work

### Boss Challenge is single-player

The wave counter, boss schedule, and arena events live in one game's challenge systems. Two clients each running "their own" challenge will drift (merged waves, reused actors, boss early/late).

**Plan:** Host is the only client allowed to advance logical wave/boss phase. Guest may still let the game spawn locally, but **phase gates** (start next wave, open boss, end run) follow the host's SP line. If guest challenge state disagrees, guest force-aligns (skip waits, wake/pull policy already in SP) rather than advancing on its own.

### Enemy identity for pairing

Night Operation stamps spawn keys (`0xD8000000` range). Boss Challenge enemies often have no stable mod-readable wave key outside a networked game (Night Operation already documents this).

**Plan, in order:**

1. Probe whether challenge spawns expose any usable id in the SP arenas.
2. If not, pair by `(charId, spawn-order in wave, gate index)` within a short time window after each host wave mark — same idea as Night Operation's "new body near spot" finder.
3. If pairing stays fragile past mid-run, switch those waves to Option B custom spawns while keeping the arena map.

### Night line capacity

Today: 5×8 masks, levels `easy|normal|hard|nightmare|range`.

SP needs roughly:

- `wave` 0–20
- phase including `boss10`, `boss20`, `mod5`, `mod15`, `hazard`
- modifier ids (2) + hazard id
- larger found/killed masks or a different encoding (per-wave slot lists, or "alive count + checksum" plus reliable kill events)
- difficulty id (`d1`…`d5`, `omega`)

That is a **protocol bump** (15+), a sibling line (`sp …` beside `h`/`g`), or a careful extension of the night codecs. Prefer a dedicated `sp` line so Night Operation stays stable.

### Bosses

Sub-boss and final boss are the hardest sync problem: arena darkening, entrance camera, multi-phase HP, summons, dual bosses (Royal Guards).

**Plan:**

1. Early co-op milestone: waves 1–9 only (no boss), prove pairing and death rules.
2. Then wave-10 boss with shared-boss path (host owns battle start / phase; guest applies arena events when in range — already sketched for Alpha bosses in Online).
3. Wave-20 and duo bosses last; allow "boss swapped" SP logic to stay host-only and report the chosen boss id on the wire.

### Modifiers and hazards

Classify each into:

- **Cosmetic / local** (announcer, music bed, screen FX) → guest applies from host ids, no world sync.
- **Player buff/debuff** → apply to local EVE on both clients from the same ids.
- **Enemy mutator** (faster, tankier, splitter rate) → must affect both worlds identically; prefer host scale lines already used for shared enemies (`enemy_hp_scale` / balance) plus SP-specific flags.
- **Arena hazard** (burning floor, radiation, bullet time) → spawn/replicate the hazard actor on both sides from one seed; never let guest roll its own.

Document the 50/25 list into those buckets before coding sync. Unknown or unstable ones stay disabled in co-op until classified.

### Ghidra verification (process lock)

Online already pins native work to a Ghidra reverse of the supported Steam build (comments and tests cite `FUN_*` addresses and “pinned build” layouts). Co-op SP inherits that rule for the whole path, not only the native DLL:

| Before coding or merging… | Check in Ghidra |
| --- | --- |
| Joint transfer into a Boss Challenge arena | How the title / Shortcut / Boss Challenge load starts a challenge map; what must be true on both clients |
| Wave counter / merged waves / boss arrival | Which functions advance challenge waves and boss schedules; what is local-only vs replicated |
| Enemy pairing ids | Whether challenge spawns write `BroadcastSpawnInfo` / EventSpawnId outside net modes 1–2 (Night Operation already notes the solo gap) |
| Partner revive | In-place respawn / death-screen paths already used by Night Operation revive |
| Hazards and enemy mutators | Actors and scale hooks that both worlds must apply from one host id |
| NIKKE / Omega gate | How the game (or SP) detects DLC ownership in this build |

A spike or PR that only “worked once in game” without a Ghidra cross-check is incomplete for co-op SP. When Ghidra and in-game disagree, trust the binary for offsets and re-test in game for behaviour.

### UE4SS and packaging — locked direction

**Target:** one install on **Stellar Blade UE4SS 1.3** (Nexus 2952), with:

| Piece | Path |
| --- | --- |
| UE4SS | Stellar Blade UE4SS 1.3 (`08a0733`) |
| Survival Protocol | `ue4ss/Mods/RoguelikeMode/` (Scripts: `main.lua` **lua391**, `spmenu.lua` v61, `hazards.lua` **v56**, `announcer.lua` v6) + Announcer/Music helpers |
| SP data | `Content/Paks/~mods/RoguelikeMode_P.*` |
| Stellar Blade Online | `ue4ss/Mods/StellarCoop/` |
| Outfits | CNS (DekCNS) as SP already requires |

**Status (checked 2026-10-31 ~16:10 PT):** branch `sp-ue4ss13-port` tip `d3068342` — **Survival Protocol 0.1.5-beta / main lua391** (Nexus page updated). Companions: hazards v56, spmenu v61, announcer v6. Official requirement is now UE4SS 1.3 (Nexus 2952); `#148` still recognised but not re-tested. NIKKE DLC is required for the whole mod (not only Omega). SP on `08a0733` still uses **ONELOOP**. Main-PC active test for 0.1.5 already had **StellarCoop loaded** alongside RoguelikeMode.

**Unsupported:** SP built only for old 148 semantics without the 1.3 timer path, mixed with Online on 1.3, or two different UE4SS trees in one folder. Ghidra checks stay on Online's pinned Steam build.

### How to make 0.1.5 compatible with co-op (work order)

Compatibility is **not** “run two independent SP sessions.” It is a host-authoritative bridge:

| Where the work lives | What to build |
| --- | --- |
| **Online** (`StellarCoop`) | New `sp` wire (ask/accept/transfer/ready/wave/down/revive), reuse nightop shared-enemies + partner revive, version gate for SP 0.1.5 |
| **SP** (`RoguelikeMode`) | Small co-op hooks: detect linked role; **guest follower mode**; pause death-fail for revive; on shared success call local `M.record`; optional host invent marks |
| **Both installs** | Same UE4SS 1.3 folder: RoguelikeMode + StellarCoop + CNS + NIKKE |

Concrete sequence (do not skip ahead of the gates):

1. **Pin + co-load smoke** — both PCs on 0.1.5-beta + Online. Title, SP menu, Online F5, one solo SP run, confirm no timer/input fight. (Informal co-load already happened on the main PC during 0.1.5 active test.)
2. **Ghidra + pairing spike** — name Boss Challenge accept/travel; log three E-04 waves (class/order/spot; EventSpawnId stays 0). Decide Option A pairing vs Option B custom spawns.
3. **Guest follower API in SP** — when Online says “guest in co-op SP,” force: no fast/early kick, no resync, no boss-phase start, no stray/air/boss-centre ownership fights, no removals even if `removals` is on. Host keeps the solo kick engine.
4. **Phase 1 bridge** — host-only Co-op run row → guest ask → both `BossChallengeButtonAcceptAction` → shared ready before wave 1.
5. **Phase 2+** — host wave marks on `sp`; shared enemies if pairing holds; partner revive; personal rewards; then modifiers/hazards/bosses.

### How SP 0.1.5 and Online fit together (checkout notes)

Source of truth: `SurvivalProtocol/ue4ss_RoguelikeMode/Scripts` on `sp-ue4ss13-port` @ lua391 / 0.1.5-beta.

**Still plays well with the locked co-op design.** Joint start, personal rewards, partner-revive intercept, NIKKE gate, and ONELOOP 1.3 stack hold. 0.1.5 makes co-op *easier* in one place and *stricter* in another: enemy removals (floor/swap/carryover/leftover/zombie) are **off by default** (debugflag `removals` turns them on), so host invent divergence is rare in the shipped build; wave kicks are even faster, so guest follower mode is non-negotiable.

**Joint start maps cleanly onto SP's existing arm path.** Host picks a difficulty in `spmenu`; SP opens Boss Challenge via the lobby's `BossChallengeButtonAcceptAction()` (no longer hooked — the mod calls it). Co-op adds: guest accept → **both** clients arm the same difficulty and accept → shared ready after `ClientRestart` / arena load-in / GET READY. SP's stage-mismatch rule (lua344: loaded map decides difficulty — E04/E05/Matrix_XI/B07/C05/NK_*) must run on both sides; the host's `sp` line should carry the intended difficulty **and** abort if the guest's loaded stage disagrees.

**Rewards already match the locked design.** `spmenu.M.record(d, what, wave)` writes local `progress.txt` (`clears_*`, `subwins_*`, bests). On co-op success each PC calls the same record path against its own file — no progress sync over the link.

**Partner revive is the invasive SP change.** Solo SP ends the run on Eve's death screen (`WB_MainHUD_Dead`, with a 20 s post-load delay on 1.3). Co-op must pause that fail path while Online's interact-hold revive runs, then resume the SP wave loops without treating the down as a clear/fail.

**The hard co-op seam is wave authority vs SP's kick engine — tighter on 0.1.5.**

| Mechanism (lua391 / 0.1.5) | Behaviour | Co-op impact |
| --- | --- | --- |
| Fast kick | Arena empty **0.5 s** + wave counted **4 s+** → next phase | Guest must not kick at all |
| Early kick | 1 body left at **8 s+**, or 2 left at **20 s+** → kick before empty | Two clients early-kicking = double phase starts |
| Fast resync / re-kick | Already-kicked wave with no new count → skip ahead after hold | Guest resync drifts the counter off the host |
| Stray / air watches (lua388) | Far / mid-air bodies brought to Eve | Host-owned presentation; guest follows, does not invent teleports for authority |
| Boss to centre (lua390) | Far boss arrivals moved to arena centre | Host owns; guest mirrors position via shared-enemy / same-place |
| Removals (floor/swap/leftover/…) | **Off by default** in 0.1.5; `removals` flag turns on | Default co-op install has fewer invents; if host enables removals, guest must stay off and invent tags go on `sp` |

For two clients:

- **Host** keeps kick / early kick / watchdog / ACTIVATE / stray-air / boss-centre (owns phase).
- **Guest** must enter a **follower mode**: track bodies for shared-enemy pairing and local presentation, but **must not** kick phases, early-kick, resync counters, start boss phases, or run removals/invents on its own. Force the gate in code (Online role → SP switch), not a manual `debugflags.txt`.
- Otherwise guest kicks fight the host's `sp` line within ~0.5–1 s of a wave ending.

**Enemy pairing cannot use EventSpawnId.** SP's SPAWNINFO probe (Hard): `BroadcastSpawnInfo.EventSpawnId` is **0** on challenge bodies. Pair by `(charId / class, arrival order in wave, gate/spot)` inside a host wave mark. If host later enables `removals`, invent tags (`floor` / `swap`) must ride the `sp` line. Ghidra follow-up: `ESBActorCondition` / MetaAI before inventing guest ACTIVATE sync.

**Co-load risks to smoke before Phase 1 code:**

| Risk | Why |
| --- | --- |
| Game-thread load | SP ONELOOP every frame + Online's `LoopInGameThreadWithDelay(1)` / 250 ms loops + CNS hooks |
| Death / HUD watches | Both mods touch death UI; partner revive needs one owner |
| Title input | SP owns Boss Challenge overlay; Online F5 / pad View menu must not steal SP menu focus mid-arm |
| Second-run leak | SP RESTART REQUIRED; either client leaking aborts the shared run |
| Guest kick race | 0.1.5 empty kick at 0.5 s / early kick at 8 s — follower mode is mandatory |
| DekCNS | Outfit unlocks still need CNS; mid-session unlocks still need a game restart to appear in CNS |

### Second-run / arena memory crash

SP already warns RESTART REQUIRED between solo runs. For co-op, any client that hits it must abort the shared run. Until the solo crash is fixed, co-op guidance is **one co-op run per game process per PC**.

### Audio helper

Announcer/music stay local. No sync required beyond "both got the same modifier/hazard ids so VO lines match."

## Phased delivery

### Phase 0 — Spec lock

- **Start flow, personal rewards, partner revive, NIKKE-only co-op, Ghidra verification, and UE4SS 1.3 as the shared stack are locked.**
- Modifier/hazard classification sheet.
- Protocol sketch for the `sp` line (ask → accept → transferring → ready → count → wave…, down/revive words, plus failure words).
- Support matrix (**UE4SS 1.3 shared**, **NIKKE required for co-op**, CNS, Online protocol version, **pinned Ghidra / game build**).
- Gate: SP **0.1.5-beta / lua391** (`sp-ue4ss13-port` @ `d3068342`) + Online co-load smoke on one PC (title, SP menu, Online F5, one solo SP run).
- Spec guest **follower mode** (no phase / early kicks, no resync, no removals/invents, host-owned stray/air/boss-centre) and host `sp` line fields.
- Ghidra pass list for Phase 1 transfer + Phase 2 pairing (EventSpawnId confirmed 0 — focus class/order/gate + MetaAI/condition enums).

### Phase 1 — Host start + joint transfer

- Host starts co-op SP from the SP menu while linked; guest gets ask / refuse.
- On accept, both transfer into the same difficulty arena; neither starts waves until both report ready.
- Partner ghost visible; chat/vit work.
- Abort before wave 1 if either client fails load or reports restart-required.
- On a later success path (Phase 3+), each client applies its own next eligible unlock.

**Exit test:** two PCs leave the title together, land in E-04 with ghosts, and wait on a shared ready gate with no wave sync yet.

### Phase 2 — Host-authoritative early waves

- Host drives waves 1–5 (or 1–9) phase marks.
- Guest mirrors phase; local spawns; kill reports; shared score.
- Shared enemies on if pairing works; otherwise same-place off and score from host kills only (degraded mode, clearly labelled).

**Exit test:** two players clear early waves with one score and one fail-on-death rule.

### Phase 3 — Death and revive

- Partner revive on the `sp` line (reuse Night Operation interact-hold UX; no self-revive; `failed:both`).
- Results screen on both clients with personal unlock eligibility.

### Phase 4 — Modifiers and hazards

- Wire the two modifiers + one hazard at run start.
- Enable only the classified-safe set in co-op; disable the rest with a menu note.

### Phase 5 — Bosses

- Wave 10, then wave 20, then duo bosses.
- Boss id chosen by host; guest loads matching encounter.

### Phase 6 — Full difficulties and polish

- All six difficulties under the NIKKE-only co-op gate (both clients already own DLC).
- Music/announcer parity, loading screens, CNS unlock verification after co-op clears.
- Automated soak: host/guest bots against desync metrics (wave drift, unpaired enemies, revive races).

If Phase 2 pairing fails hard, insert **Phase 2B**: custom spawn path for co-op waves (Option B) before bosses.

## What not to do in v1

- More than two players (Steam link limit and arena density).
- Cross-play between SP-only and Online-only installs without the agreed bridge.
- Shared inventory, shared CNS unlock files, or online leaderboards.
- Depending on Shift Up matchmaking / Night Operation's cut dedicated servers (Online already refuses those).
- Quietly merging SP's GPL-adapted helpers with SP's Nexus asset packs without a packaging plan for outfits/music permissions.

## Relationship to Night Operation

Keep both modes. They answer different fantasies:

| | Night Operation | Survival Protocol co-op |
| --- | --- | --- |
| Entry | In-world / Roxanne / console | Title-screen SP menu |
| Length | ~5 timed waves | 20 waves + bosses |
| Identity | Cut Shift Up multiplayer mode | Roguelike Boss Challenge wrapper |
| Wire | Existing night line | New `sp` line (or night extension) |
| Code reuse | waves/run/revive/fight | Same, plus SP menu/rewards/hazards |

Night Operation remains the place to harden shared enemies and revive. SP co-op should consume those systems, not fork them.

## Open questions

1. Should co-op SP require a co-op save, or is the Boss Challenge / title path enough (no story save touch)? Joint transfer from the title argues for title-only, same as solo SP.
2. Which modifier/hazard pairs are known unfair even in solo, and should co-op ban them outright?
3. Is the public pitch "Survival Protocol Co-op" (SP-branded) or a mode inside Stellar Blade Online's menu that launches SP?
4. After Option A validation, is the long-term goal to retire Boss Challenge dependence entirely for both solo and co-op?
5. When to open co-op to players without NIKKE (non-Omega difficulties only), if ever?
6. Whether a later Hardcore one-life toggle is worth shipping after partner revive is proven?

## Suggested next concrete steps

**0. Co-load smoke** (pin 0.1.5-beta / lua391): one game folder with UE4SS 1.3 + RoguelikeMode 0.1.5 + `StellarCoop`. Confirm title entry, SP menu, Online F5, and one solo SP run without fighting over input or timers.

**1. Ghidra + pairing spike** (after 0), not a feature branch merge:

1. On the pinned `SB-Win64-Shipping.exe` DB, name Boss Challenge accept / arena travel, and the condition/MetaAI paths SP's ACTIVATE already probes (`ESBActorCondition`, stealth/battle). Treat EventSpawnId as unusable on Hard (confirmed 0 in SP).
2. With Online linked on two PCs, both arm the same difficulty and land in E-04 together (manual joint transfer rehearsal).
3. Log three waves: class/charId, time, position, Tags, InteractionState / battle flags, gate/spot if any.
4. Decide pairing + whether guest follower mode can keep Option A, or wave ownership must move to Option B custom spawns.

**2. First code cut after 0–1:** guest follower hook in SP + Online `sp` ask/accept/transfer (Phase 1). Do not start Phase 2 wave sync until follower mode is proven.

Do not skip the Ghidra pass for speed.

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
7. **Shared UE4SS 1.3 stack.** Co-op SP targets the same UE4SS as Stellar Blade Online: **Stellar Blade UE4SS 1.3** (the package Online already requires). The SP port onto that stack **already works**; it still needs to be copied to the author's main PC and committed/published (expected the same day as this note). Co-op bridging assumes that published 1.3 SP build — do not plan a dual-UE4SS or “port Online onto 148” path.

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
| Stack | Stellar Blade UE4SS 1.3 (same as Online; was Nexus 148 / 3.1.0 — 1.3 port works, publish pending); CNS for outfits; NIKKE DLC for Omega |

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
- SP on UE4SS 1.3 already works locally; public/main-PC publish is pending so both mods can share one documented install.
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
**Cons:** Still fights Boss Challenge's single-player guts; second-run arena crashes become a two-PC problem; needs the published SP 1.3 build on both players' installs.

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

**Target:** one install on **Stellar Blade UE4SS 1.3**, with Survival Protocol and Stellar Blade Online loaded together. That matches Online's current requirement and removes the old dual-stack fork (SP on Nexus 148 vs Online on 1.3).

**Status (author):** the SP UE4SS 1.3 port **already works**. Transfer to the main PC and the GitHub/Nexus commit are still pending (expected today). Once that build is the one players install, co-op bridging can use a single documented stack. Until then, treat “SP 1.3 on main + Online” as the co-load smoke to confirm when the files land.

**Unsupported:** mixing SP-on-148 with Online-on-1.3 in one game folder. If someone still has the old SP UE4SS, Co-op run stays refused with a clear version notice. Ghidra checks stay on Online's pinned Steam build either way.

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
- Gate: published SP 1.3 on main + Online co-load confirmed (port itself already works).
- Ghidra pass list for Phase 1 transfer + Phase 2 spawn id fields (addresses named before implementation).

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

**0. Publish SP on UE4SS 1.3** (works locally; main-PC transfer + GitHub/Nexus commit expected today), then confirm SP + Online load together on that published build.

**1. Ghidra + pairing spike** (after 0), not a feature branch merge:

1. On the pinned `SB-Win64-Shipping.exe` DB, locate Boss Challenge / MultiPlay / spawn-broadcast paths for arena start and enemy spawn ids (including whether EventSpawnId is copied outside net modes 1–2). Write down the `FUN_*` names and what each client would see in a standalone game.
2. With Online linked on two PCs (or one PC + loopback where possible), load Boss Challenge arena E-04 on both.
3. Log every enemy spawn for 3 waves: charId, time, position, any key/id fields Ghidra said to expect, controller presence.
4. Decide pairing strategy from the Ghidra notes + that log before writing protocol or menu work.

That spike answers whether Option A is viable past early waves, or whether planning should pivot to Option B immediately. Do not skip the Ghidra pass for speed.

# Survival Protocol Co-op — Feasibility Plan

This is a design plan, not an implementation. It asks how [Survival Protocol](https://www.nexusmods.com/stellarblade/mods/4009) (SP 0.1.4-beta: title-screen roguelike, 20 waves, one life, six difficulties) could become playable for two players, and what of Stellar Blade Online (this repository) already covers the hard parts.

Related reading in this repo: [Night Operation](night-operation.md) (wave co-op already built), [How it works](how-it-works.md) (Steam link, shared enemies, night line), [README credits](../README.md#credits) (SP code already adapted into Night Operation).

## Verdict

Co-op Survival Protocol is possible, but not by running two independent Boss Challenge sessions and hoping they stay in sync. The workable shape is **host-authoritative run state over Stellar Blade Online's Steam link**, with each PC still simulating its own arena copy, the same pattern Night Operation already uses.

The main fork in the road is whether SP keeps riding the game's Boss Challenge mode, or whether co-op waves are rebuilt on Night Operation's custom spawn path. That choice decides almost everything else.

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
| Stack | UE4SS 3.1.0 (Nexus 148); CNS for outfits; NIKKE DLC for Omega |

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
| Friend revive | Interact-hold revive; SP would need a design choice, not new plumbing |
| CNS outfit ghost | Partner's SP unlocks can show if both have the CNS packs |
| Co-op saves | Isolate experiment from story progress |

Gaps relative to SP:

- Night line masks cover **5 waves × 8 slots**. SP needs **20 waves**, bosses, modifiers, hazards, and a longer phase vocabulary.
- Only the Shooting Range challenge is marked `coop=true` today; swarm / skulls / gauntlet stay solo.
- Steam link is **two players**. SP's fantasy can stay at two for a first co-op cut.
- UE4SS packaging differs: SP targets Nexus 148 (3.1.0); this mod targets the UE4SS 1.3 package. Both mods cannot assume one install without a stack decision.
- Boss Challenge itself has **no multiplayer replication**. The game never ships a dual-client challenge run.

## Architecture options

### A — Bridge SP through Stellar Blade Online (recommended first cut)

Keep SP's identity (title entry, difficulties, modifiers, hazards, rewards). When a Steam session is up, SP hands **run authority** to a co-op layer that speaks the existing night-style wire (or a sibling `sp` line on channel 0).

```
  title SP menu (host picks difficulty + starts)
           |
           v
  both clients load the same Boss Challenge arena
           |
           +-- host: runs challenge / watches waves / rolls modifiers
           |         encodes SP state on the link
           +-- guest: loads same arena, mirrors host phase,
                     fights local copies, reports kills / death
           |
           v
  shared-enemy pairing on arena mobs + partner ghost
```

**Pros:** Reuses SBO's hardest infrastructure; SP stays the product the player opens; outfit/music progress can stay in SP's files.  
**Cons:** Still fights Boss Challenge's single-player guts; second-run arena crashes become a two-PC problem; UE4SS stack must be reconciled.

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

### 1. Lives

| Model | Feel | Fit with existing code |
| --- | --- | --- |
| Classic SP: either death ends the run | Harsh, closest to solo SP | Night Operation's `failed:host` / `failed:guest` |
| Shared down + partner revive | Co-op fantasy, less punishing | Night Operation revive (30 s, interact hold, optional self-revives) |
| Shared life pool (e.g. 3 downs for the team) | Roguelike middle ground | Small extension of night line down words |

**Suggestion for a first public co-op beta:** partner revive with **no self-revive**, and fail when both are down (Night Operation's `failed:both`). Keep a "Hardcore" toggle later for classic one-life.

### 2. Who rolls the run

Host rolls difficulty (already chosen), the two modifiers, and the hazard once at ask-time. Guest receives them on the wire and applies local-only presentation (announcer lines, HUD). World-affecting hazards must be applied on **both** clients from the same seed/ids, never rolled twice.

### 3. Score and rewards

- **Score:** host-authoritative, same as Night Operation (a kill counts once across worlds when shared enemies are on).
- **Unlocks:** personal. Beating a co-op run unlocks on **each** PC that finished the success state, so neither player is gated on the other's CNS folder. Failures unlock nothing.
- **Best runs:** local `records`-style files; no cross-PC leaderboard in v1.

### 4. Start flow

Host opens SP → picks difficulty → "Co-op run" (only while linked) → guest auto-prompted → both load the arena → shared GET READY → wave 1. Guest cannot start a co-op SP run. Solo SP stays unchanged when no session is up.

### 5. Distance and camera

Arenas are compact enough that ghost + shared enemies matter more than long-range travel. Still need a rule when the guest is not in the arena yet (refuse join) and when one client softlocks on the second-run crash (abort both with a clear "restart required" outcome).

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

### UE4SS and packaging

SP and Online do not share a supported UE4SS story today. Co-op SP needs one explicit support matrix, for example:

- Co-op SP requires Stellar Blade Online + SP content packs on **Online's** UE4SS, or
- Online's native DLL is loaded beside SP on SP's UE4SS after a dedicated port.

Treat "both mods installed on mismatched UE4SS" as unsupported, with a title-screen notice.

### Second-run / arena memory crash

SP already warns RESTART REQUIRED between solo runs. For co-op, any client that hits it must abort the shared run. Until the solo crash is fixed, co-op guidance is **one co-op run per game process per PC**.

### Audio helper

Announcer/music stay local. No sync required beyond "both got the same modifier/hazard ids so VO lines match."

## Phased delivery

### Phase 0 — Spec lock

- Lives model, reward rules, start flow (decisions above).
- Modifier/hazard classification sheet.
- Protocol sketch for the `sp` line (fields, rate limits, failure words).
- Support matrix (UE4SS, NIKKE, CNS, Online protocol version).

### Phase 1 — Session + arena presence

- Host starts co-op SP from the SP menu while linked.
- Guest receives ask / can refuse (wrong map, not ready, no NIKKE for Omega, etc.).
- Both load the same difficulty arena; partner ghost visible; chat/vit work.
- Abort if either client fails load or reports restart-required.

**Exit test:** two PCs stand in E-04 together with ghosts and no wave sync yet.

### Phase 2 — Host-authoritative early waves

- Host drives waves 1–5 (or 1–9) phase marks.
- Guest mirrors phase; local spawns; kill reports; shared score.
- Shared enemies on if pairing works; otherwise same-place off and score from host kills only (degraded mode, clearly labelled).

**Exit test:** two players clear early waves with one score and one fail-on-death rule.

### Phase 3 — Death and revive

- Implement the chosen lives model on the `sp` line (reuse Night Operation revive UX where possible).
- Results screen on both clients with personal unlock eligibility.

### Phase 4 — Modifiers and hazards

- Wire the two modifiers + one hazard at run start.
- Enable only the classified-safe set in co-op; disable the rest with a menu note.

### Phase 5 — Bosses

- Wave 10, then wave 20, then duo bosses.
- Boss id chosen by host; guest loads matching encounter.

### Phase 6 — Full difficulties and polish

- D2–D5 and Omega (NIKKE gate on both clients).
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

1. Should co-op SP require a co-op save, or is the Boss Challenge path title-only enough (no story save touch)?
2. Which modifier/hazard pairs are known unfair even in solo, and should co-op ban them outright?
3. For Omega, if only one player owns NIKKE, is the run blocked or does the host fall back to D5?
4. Is the public pitch "Survival Protocol Co-op" (SP-branded) or a mode inside Stellar Blade Online's menu that launches SP?
5. After Option A validation, is the long-term goal to retire Boss Challenge dependence entirely for both solo and co-op?

## Suggested next concrete step

A spike, not a feature branch merge:

1. With Online linked on two PCs (or one PC + loopback where possible), load Boss Challenge arena E-04 on both.
2. Log every enemy spawn for 3 waves: charId, time, position, any key/id fields, controller presence.
3. Decide pairing strategy from that log before writing protocol or menu work.

That spike answers whether Option A is viable past early waves, or whether planning should pivot to Option B immediately.

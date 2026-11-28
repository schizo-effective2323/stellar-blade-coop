# Survival Protocol as an SBO module

This replaces the older bridge plan on branch `cursor/survival-protocol-coop-plan-86e4`
(`docs/survival-protocol-coop.md`). That plan kept Survival Protocol (SP) as a separate UE4SS mod
(`RoguelikeMode`) that talked to Stellar Blade Online (SBO) through files, then later through
`spnet.dll`. This plan brings SP into this repository as one SBO module. It uses SBO's Steam Link,
ghosts, revive and shared enemies. It ships no `spnet.dll` beside `StellarCoop.dll`.

Source pin for the import: `schizo-effective2323/schizo-effective-mods` branch `sp-coop-phase1` tip
`873b240` (SP 0.1.8 hotkey audit). Checkout on this machine: `/agent/repos/schizo-effective-mods`.

**Go (2026-11-27, America/Creston):** Schizo approved converting imported SP scripts to the SBO
License 1.0 and aligning the module with MotherSphere's guidelines (module layout, Link only, no
`spnet.dll`). Coding may proceed on `sp-module`.

## Goal

Players install one Online stack. Survival Protocol runs as module `online.modes.sp` under
`StellarCoop`. Host and guest link through SBO. They see each other as SBO ghosts. They share
enemies through `fight.enemies`. A downed partner uses SBO's revive. The SP menu, arenas, waves,
modifiers, hazards and unlocks stay SP's product surface.

## Locked decisions

1. **One DLL.** `StellarCoop.dll` owns Steam. No `spnet.dll`, no second Steam worker, no
   `RoguelikeMode\net\` out/in files.
2. **Module folder.** New module `online.modes.sp` at `mod/StellarCoop/Scripts/online/modes/sp/`,
   with matching `tests/lua/online/modes/sp/` and docs under `docs/online/modes/`. Native parts only
   if a later spike proves Lua plus existing shared pieces cannot do a job. Ask before any shared
   `link/` or `glue/` change.
3. **SBO Link for session.** Host / join / leave / invite go through `M.link.request(...)`, the same
   words Online already uses (`host`, `join`, `leave`, `invite`). The SP menu draws the buttons. It
   does not open its own Steam lobby.
4. **SBO ghosts for the partner.** Drop SP's unreliable `pe` position stream and the SkeletalMeshActor
   puppet (`lua457`–`lua485`). `online.partner` already builds the remote EVE from the pose path on
   channel 1.
5. **SBO revive for a downed partner.** Reuse `online.group`'s interact-hold revive (and the Night
   Operation pattern that already owns revive during a run). Do not rebuild SP's death-screen hide
   from scratch. Group already credits SP for that idea.
6. **SBO shared enemies for the arena.** Turn on `fight.enemies` for SP runs (same place as a later
   option). Pairing still needs an SP-side plan for Boss Challenge spawns that lack Night Operation
   spawn keys.
7. **Run state on a mode line.** Carry SP's host/guest run lines on the Link mode line with word
   `sp` (`M.link.mode_line('sp', text)` / `take_mode('sp')`). Do not overload Night Operation's
   `coop-night.txt` line. Fishing and photo hunt already use this path.
8. **Keep SP git history when practical.** Import with `git subtree` (or `git filter-repo` then
   subtree) from `schizo-effective-mods` so `SurvivalProtocol/` commits stay reachable. If the
   filter is too noisy (dev_builds, cooked leftovers), import a filtered subtree of
   `SurvivalProtocol/ue4ss_RoguelikeMode/Scripts` plus the unit tests and native `spnet` sources for
   reference only. Prefer history over a flat copy.
9. **Push only `sp-module`.** Never force-push. No AI `Co-authored-by` lines. No pull request into
   MotherSphere's upstream. PRs stay on Schizo's fork into `dev` when asked.
10. **License (locked 2026-11-27).** Imported SP scripts in this repository are licensed under the
    SBO License, version 1.0 or any later version the Licensor publishes, same as the rest of SBO.
    SchizoEffective (copyright holder of Survival Protocol) approved that move. Pak / Announcer /
    Music / CNS assets stay install-time outside the open tree until packaged under the same terms.
    Do not copy MotherSphere code back into the closed mods repo.

## What SP has today (sp-coop-phase1)

| Piece | Where | Role |
| --- | --- | --- |
| Run loop | `SurvivalProtocol/ue4ss_RoguelikeMode/Scripts/main.lua` (lua485) | Boss Challenge arenas, 20 waves, hazards, Tachy partner, co-op phase 2 follower |
| Menu | `spmenu.lua` / `coopmenu.lua` | SP UI; co-op hub (host, find, invite, leave) |
| Bridge API | `coop.lua` v4 | Host/guest `h sp` / `g sp` lines, follower marks, invite list |
| Transport | `spnet.lua` + `native/spnet/` (`spnet.dll`) | Own Steam lobbies (`sp_game=survival_protocol`), P2P send r/u |
| Partner view | `pe` unreliable messages + puppet Eve | Position only; not SBO's pose ghost |
| Tests | `SurvivalProtocol/tests/coop_test.lua`, `coopmenu_test.lua` | Fake net / fake DLL |

`spnet` marks lobbies with `sp_game` / `sp_proto`. SBO marks them with `stellarcoop`. After the
move, SP sessions are normal SBO online sessions. Optional later work: a lobby data key such as
`sbo_sp=1` so Find a session can filter SP hosts.

## How each SBO system carries SP

### Link (replaces spnet.dll)

```
  SP menu Host / Join / Leave / Invite
           |
           v
  online.modes.sp  -->  M.link.request('host'|'join'|...)
           |
           v
  StellarCoop.dll (native/src/link/)  -->  Steam lobbies + channels
           |
           +-- channel 0: mode line word `sp` (run state, reliable)
           +-- channel 1: pose path (ghosts; SP sends nothing extra)
           +-- channel 2: fight lines (shared enemies; fight.enemies owns them)
```

Map today's `coop.lua` / `spnet` verbs:

| SP today | SBO after |
| --- | --- |
| `net.cmd('host public\|friends')` | `M.link.request('host public')` / `host` (friends) |
| `net.cmd('join <lobby>')` / `find` | `join` / session list; SP browser UI may wrap SBO's list later |
| `net.cmd('invite [<id>]')` | `invite` |
| `net.cmd('leave')` | `leave` |
| `net.cmd('send r <h sp …>')` | `M.link.mode_line('sp', '<h|g sp …>')` |
| `net.cmd('send u pe …')` | **delete**; ghosts replace it |
| `net.cmd('loopback on')` | `coop loopback` (existing) |
| `spnet` in.txt `linked` / `friend` | `coop-status.txt` `link=` / `friend=` / `member=` |
| `spnet` friends lists | SBO status `ingame_friend` / online friends (fork already had these) |

Title-screen join: Phase 1 on spnet joined without a loaded save. SBO still holds overlay invites until
`world=1`. For SP-from-title, either keep "press Join on the SP menu" (Phase 1 behaviour) or ask for a
narrow shared-piece exception that allows join while the SP module reports its menu is up. Prefer the
menu Join path first. It needs no Link change.

### Ghosts (replaces pe + puppet)

During an SP run both players are in an online session. `online.partner` builds each remote EVE.
SP's module must:

- stop building `rlCoopPuppet` and stop calling `sendFast('pe …')`;
- treat "partner visible" as "ghost slot for that member is up", through `uses` on
  `online.partner` (late reads only);
- keep SP's own Tachy CPU ally as local SP logic (not a ghost).

CNS outfit ghosts already cover SP unlocks when both PCs have the packs.

### Revive (replaces Phase 3 invent-from-scratch)

`online.group` already revives a downed EVE with a 3 s interact hold next to the ghost. Night
Operation takes ownership of revive during its run and calls the same path. SP should do the same
shape:

- while an SP run is active, the SP module owns down / fail rules (`failed:both` when both are down
  with no revive under way);
- partner revive = group's call (or a thin copy of Night Operation's `night_revive` wiring inside
  the SP module if group's export is not enough);
- no self-revive in the first co-op cut (matches the old plan's locked decision);
- hide the death screen only through the existing group path.

### Shared enemies (replaces dual independent Boss Challenge HP)

`fight.enemies` shares HP, balance, knockdowns and kills for paired copies. For SP:

- host starts `coop fight` (or the module asks the same native path) when an SP co-op run enters the
  arena;
- guest follows;
- pairing: Boss Challenge often has no `EventSpawnId` outside net modes. First try
  `(charId, wave order, gate)` within a short window after each host phase mark. If mid-run pairing
  fails, move those waves to custom spawns (old plan Option B) without leaving the SP module.

Same place stays experimental and host-gated, as Online already does.

## Module shape (when coding starts)

Follow [docs/dev/modding/new-module.md](../dev/modding/new-module.md) and
[structure.md](../dev/structure.md):

1. `python3 -I tools/new_module.py online/modes/sp --title "Survival Protocol"` (skeleton).
2. Move / adapt SP scripts into that folder by job: `run/`, `menu/`, `hazards/`, `coop/` (bridge that
   talks only to `M.link` and listed `uses`). No `require` of another module's files.
3. `uses` will likely include `online.partner`, `online.group`, `fight.enemies` (and only those the
   wiring actually reads).
4. Register in `MODULES`, language `modules` tables, `install_test.py`, docs tables.
5. Port `SurvivalProtocol/tests/coop_test.lua` to fake `M.link` instead of fake `spnet`.
6. Leave `native/spnet` out of the ship. Keep it in the mods checkout as history. Do not build it
   into `StellarCoop.dll`.

Pak data (`RoguelikeMode_P`), Announcer / Music helpers and CNS outfits stay install-time assets.
The open module must not invent game addresses. Ghidra on build 26123051 before any new native or
engine call.

## Import steps (after go)

1. Confirm license choice (relicense scripts vs closed assets + open bridge).
2. On `sp-module` (from current `dev`): subtree-merge a filtered history of
   `SurvivalProtocol/` from `schizo-effective-mods` `sp-coop-phase1` into something like
   `third_party/survival-protocol/` or straight into `online/modes/sp/` after the skeleton exists.
   Prefer a dedicated import commit that only adds history, then commits that rearrange into the
   module layout.
3. Delete or quarantine `spnet.dll` load paths (`spnet.lua` loadlib). Replace with Link adapters.
4. Wire Host / Join to `M.link.request`. Prove a two-PC or loopback link with mode line `sp` before
   touching waves.
5. Disable puppet / `pe`. Confirm SBO ghosts in an SP arena.
6. Turn on shared enemies for the run. Measure pairing on D1 waves 1–3.
7. Hook revive through group. Test `failed:both`.
8. Follower / host phase marks already in `coop.lua` move onto the mode line unchanged in spirit.

Push each working step to `sp-module` only.

## Phased delivery on this branch

| Phase | Outcome | Depends on |
| --- | --- | --- |
| P0 | This plan + license decision | Schizo go |
| P1 | Module skeleton; Link Host/Join/Leave; `sp` mode line carries today's host/guest state; no spnet | Link + menu |
| P2 | Ghosts only (no puppet); joint arena start; host phase marks / guest follower | `online.partner` |
| P3 | Shared enemies on SP waves (early difficulties) | `fight.enemies` pairing spike |
| P4 | Partner revive + `failed:both` | `online.group` |
| P5 | Modifiers / hazards host-authoritative | classification list |
| P6 | Bosses 10 / 20; polish; optional `sbo_sp` lobby tag | P3–P5 |

## Explicit non-goals for the first cut

- Shipping `spnet.dll` next to `StellarCoop.dll`.
- A second Steam lobby namespace (`sp_game`) beside SBO's.
- Replacing SBO ghosts with the pe puppet.
- Opening a PR to `MotherSphere/stellar-blade-coop`.
- Force-pushing `sp-module` or `dev` / `main`.
- Changing shared `link/` / `glue/` without a separate ask (mode line word `sp` needs no protocol bump;
  the mode line already exists).
- Self-revive in SP co-op v1.
- More than two players in an SP run.

## Risks

| Risk | Mitigation |
| --- | --- |
| License clash (closed SP into open SBO) | Decide before import commit |
| Boss Challenge desync on two clients | Host phase authority; Option B custom spawns if pairing fails |
| Title invite held until save load | Menu Join path first |
| Hotkey clash (F7 follow vs SP) | Already audited in SP 0.1.8; re-check after module keys |
| Module isolation rules | No cross-requires; copy with attribution line when needed; `modules_test.py` |
| Large binary / build noise in mods history | Filter subtree; do not import `dev_builds` |

## Status

License decision 10 is locked. Implementation starts with P1 on `sp-module`: module skeleton, Link
Host/Join, mode line `sp`, no `spnet.dll`. Larger run / menu / hazards imports follow in later
commits on the same branch.

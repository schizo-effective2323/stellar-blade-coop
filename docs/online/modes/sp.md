# Survival Protocol

Module `online.modes.sp`. It brings Survival Protocol's online-session bridge into Stellar Blade Online under
the SBO License. It uses SBO's Steam Link. It ships no `spnet.dll`.

The plan is in [docs/plans/sp-module.md](../../plans/sp-module.md).

## What players see

| Command | What it does |
| --- | --- |
| `coop sp` / `coop sp status` | Link role, whether a partner is linked, protocol version |
| `coop sp host` / `coop sp host friends` | Host a friends-only online session |
| `coop sp host public` | Host a public online session |
| `coop sp join` | Join a friend's online session |
| `coop sp leave` | Leave the session |
| `coop sp invite` | Open Steam's invite dialog |

The Survival Protocol menu, arenas, waves, modifiers and hazards are not in this module yet. Ghosts stay
`online.partner`. Revive stays `online.group`. Shared enemies stay `fight.enemies`.

## How it works

`coop.lua` encodes host and guest run lines (`h sp …` / `g sp …`) and sends them on the Link mode line with word
`sp` (`M.link.mode_line` / `take_mode`). Session verbs call `M.link.request`. The old unreliable `pe` position
stream is dropped (`sendFast` returns false).

A 250 ms tick in `main/pass.lua` is not wired yet. That file is a shared piece. It waits for MotherSphere's OK.

## Tests

`tests/lua/online/modes/sp/off_test.lua` checks load isolation.
`tests/lua/online/modes/sp/sp_test.lua` checks `coop sp`.
`tests/lua/online/modes/sp/coop_test.lua` checks encode/decode and two fake Links through a host/guest run.

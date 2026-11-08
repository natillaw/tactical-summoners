# Plan: Warrior — next steps for continued testing

**Branch:** `overhaul/warrior` (11 modified files, ~1700 insertions, uncommitted)

## Current state (verified by reading code)

- **WarriorKit data layer is complete:** `combat/warrior_kit.gd` — M1, M2, PASSIVE (Vengeful Fury), 15 Skill Book skills, SPECIAL (Iron Counter), ULTIMATE (War God's Descent). All `implemented: true` and `selectable: true` per tests.
- **Simulation:** `game/sim/warrior_sim.gd` — handles cast types melee/line/aoe/dash/leap/banner/buff/counter, Rage, Ultimate Charge, cooldowns, buffs, counter window (`_counter_pending`/`_resolve_counter`), death/reset, snapshot.
- **Dummy:** `game/sim/dummy_sim.gd` — telegraph, attack, respawn, slow/vulnerable/interrupt effects.
- **Presentation:** Arena, WarriorActor, DummyActor, HUD, LoadoutPanel, VFX (slash_arc, impact_burst, fx_sprite, pixelfx_library), SFX.
- **Input:** `game/input_setup.gd` — M1/M2 mouse, Space/Q/E/R/F slots, Tab loadout, F2 reset, F4 refill, F3 debug.
- **Tests:** `tests/test_warrior_sim.gd`, `tests/test_warrior_data.gd`, `combat/tests/test_warrior.gd` (headless via Godot).

## Key discrepancy to resolve

`docs/design/WARRIOR.md` ("Qué falta para cerrar el Warrior", lines 203-216) claims:
1. Special Iron Counter — solo datos
2. Ultimate War God's Descent — solo datos
3. 15 skills — solo datos

But tests (`test_warrior_data.gd`, `test_warrior.gd`) now assert all 17 abilities are `implemented: true` and `selectable: true`, and `warrior_sim.gd` already contains cast-type logic for counter/dash/leap/banner/buff. **Confirm which of these are genuinely playable vs. data-only before building on them.**

## What's genuinely next (per WARRIOR.md + code gaps)

1. Finish Special Iron Counter gameplay (counter-stance window, deflection, response) — verify it's wired end-to-end.
2. Finish Ultimate War God's Descent (zone marker, leap, falloff damage from center, brief interruption).
3. Wire the 15 skills' effects (slow / vulnerable / interrupt) end-to-end through the sim → dummy → presentation.
4. Real enemies (beyond the dummy) with blockable attacks.
5. Balance validation (damage, times, Rage vs. varied resistance).
6. Animations (hurt, death, directional attacks) + audio variety.

## How to run / test (execute with an implementation-capable agent or manually)

```powershell
# Full headless test suite
pwsh -File tools/run_tests.ps1

# Single warrior sim suite
'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\dev\combat' --script tests/test_warrior_sim.gd

# Single warrior data contract suite
'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\dev\combat' --script tests/test_warrior_data.gd

# Interactive play (to keep testing the warrior feel)
'C:\Users\natha\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --editor --path 'C:\dev\combat'
# Controls: WASD move, mouse aim, LMB M1 slash, RMB M2 heavy, R reset, F4 refill, Tab loadout, F3 debug
```

## Validation plan

- `pwsh -File tools/run_tests.ps1` exits 0 (all suites PASS).
- Add tests for: counter-stance deflection window, ultimate charge gain/spend, each skill's effect applied to dummy, rage decay, buffer input.
- If adding skills/effects, update `docs/design/WARRIOR.md` and `docs/ARCHITECTURE.md` per AGENTS.md.

## Open decision (asked before implementing)

Confirm whether Iron Counter and War God's Descent are genuinely playable today or still data-only, so the next slice targets the right gap. Recommended answer: treat them as "partially wired" — verify via a focused headless test, then finish the missing stance/marker/falloff gameplay.

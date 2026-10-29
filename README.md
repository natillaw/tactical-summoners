# Tactical Summoners - Drop C (summons v2 + real-time sandbox + combat + mission + memorial)

Summoning v2 (data-driven banners, seeded summon log, Trust/Obedience/Composure, event ledger, save v2) + real-time control sandbox (map, camera, selection, move orders). Godot 4.x, 2D, GDScript. Drop B was tested headless on Godot 4.4.1; Drop C additions are untested until you run the suites.

## Run the tests (no editor needed)
`powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1` -> 7 suites, writes tools\last_test_run.txt. NOTE: Drop C was written without running Godot; send me tools\last_test_run.txt.

## Run it
1. Unzip anywhere.
2. Godot Project Manager -> Import -> pick `project.godot`.
3. Open it (first open imports the sprites, takes a few seconds), press F5.

Progress is saved automatically (user://save.json). Debug buttons on the main menu give gems/stones/books and reset the save.

## Where things live
- `scripts/data/hero_tables.gd`   classes, traits, passives, backgrounds, names, per-star rules (add content HERE)
- `scripts/core/gacha.gd`        rates, pity, cost
- `scripts/core/hero_generator.gd`  seed -> full hero (look, class, name, traits, passives, background)
- `scripts/core/sprite_composer.gd`  stacks the Tiny Pixel Fantasy layers
- `scripts/autoload/game.gd`     state, pulls, training, promotion, party, save/load
- `scripts/ui/`                  screens and widgets, all built in code
- `scripts/data/summon_config.gd` banners: odds, pity, costs (validated; edit numbers HERE)
- `scripts/sandbox/`             real-time sandbox: map, hero movement, camera/selection/orders
- `scripts/sandbox/combat_rules.gd`, `sandbox_enemy.gd`, `skill_tables.gd`, `sandbox_relic.gd`   combat numbers, enemy, skills, objective
- `scripts/ui/memorial_screen.gd`  list of fallen heroes (menu -> Memorial)
- `tests/`                       test_core, test_summons, test_memorial, smoke_ui, smoke_sandbox, smoke_combat, smoke_mission (run with tools\Run-Tests.ps1)

## Sandbox controls
LMB select / drag box, RMB move, 1-5 focus hero, Tab group view, G squad, Q skill, S stop.
Mission: grab the RELIC (far room, top right) and bring it to EXIT. Dead heroes are gone for good.

## Assets
Sprites are the Tiny Pixel Fantasy Character Generator layers (assets/sprites). Read its EULA
(link in assets/sprites/EULA_READ_ME.txt) before sharing or selling the game.

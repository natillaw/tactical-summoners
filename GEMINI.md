# GEMINI.md - Tactical Summoners

@./infos/AGENTS.md

The shared protocol above (AGENTS.md) is mandatory. Everything below is extra for Gemini CLI.

## Start of every session
1. Run `/ts:start` (or read `CONTEXT_LITE.md` yourself).
2. State the `STATE_HASH`, the single task you will do, and a 5-line plan. Then wait for the owner's OK.
3. Claim the task before touching files: `python tools/sync/ts_sync.py claim T-xxx --agent "Gemini"`.

## The project in 6 lines
- Godot 4.4, GDScript, 2D pixel art. Real-time hybrid RTS: squads of 5 heroes, autonomous heroes + direct player orders, no pause, no time-slow.
- Heroes are generated once from a saved seed and never re-rolled. Permanent death with a memorial (D-011).
- Hero art is the Tiny Pixel Fantasy style: **16x16 style**, 48x48 sheet cells, 12x8 frames per layer.
- Combat numbers are provisional (D-012): they live in `scripts/sandbox/combat_rules.gd` and the skill library.
- Skills: one library, 4 actives + 1 ultimate per hero, levels 1-70 (D-022).
- The authority order when files disagree is in AGENTS.md. `DECISIONS.md` always wins.

## Environment (owner is on Windows)
- Shell is PowerShell. Use `python` (or `py` if `python` is not found) for `tools/sync/ts_sync.py` and `tools/gen_skill_library.py`.
- Tests: `powershell -ExecutionPolicy Bypass -File tools\Run-Tests.ps1`. If Godot is not found, ask the owner for its path and pass `-Godot "C:\path\Godot.exe"`.
- Never claim anything works unless you ran it. Quote the command and the PASS/FAIL result in your log entry.
- Ask before: deleting files, overwriting more than one file at once, `git push`, `git reset`, or anything outside this folder.

## GDScript rules learned the hard way
- Use 4 spaces, never tabs. Type your variables.
- Do not write `var x := arr[0]` when `arr` is an untyped Array (Variant has no inferable type): write `var x: Type = arr[0]`.
- Do not store a typed-array literal directly in a typed field; use `.append()` or build the typed array first.
- `class_name` must be unique across the project. New `class_name` scripts need a headless import before tests see them (Run-Tests does this).
- Lambdas may change member variables but not captured local variables.
- Match existing style in the file you edit. Preserve existing work; read the file before changing it.

## Generated files: never edit by hand
- `scripts/data/skill_library_data.gd`, `docs/SKILL_LIBRARY.md`, `docs/SKILL_LIST.txt`: edit `tools/gen_skill_library.py`, then run `python tools/gen_skill_library.py`.
- `CONTEXT_LITE.md`, `CONTEXT_BUNDLE.md`: rebuilt by `python tools/sync/ts_sync.py lite` / `bundle`.

## End of every session
Run `/ts:finish`. It writes the log entry, rebuilds the context files and runs `ts_sync check`.

## Safety
- Never write API keys or tokens into any file. The Gemini key lives in the `GEMINI_API_KEY` environment variable or the CLI login.
- `assets/` contains third-party art with licenses. Do not publish or copy it elsewhere; record any new pack in `docs/ai-context/ASSET_MANIFEST.md`.

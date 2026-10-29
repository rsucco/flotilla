# Flotilla

Turn-based naval strategy game (Battleship meets XCOM) on a 15x15 hex grid. Players buy a fleet with points; ships have weapons, special/secondary abilities, passives, and drawbacks. The README is the design spec for ship rules — keep code and README in sync when rules change.

## Current State
- **Godot 3.x** project (`config_version=4` in `project.godot`). The installed `godot` is 4.x — do not open or run this project with it until the migration branch exists. It will trigger project conversion.
- `godot3-bin` (AUR) is not currently installed, so the 3.x project can't be run, built, or headless-checked on this machine.
- Legacy code predates the global style rules: untyped GDScript, PascalCase filenames, flat layout at repo root, `get_parent()` chains (e.g. `ships/Ship.gd`). Don't mass-restyle 3.x code; that happens during the port.
- Local hot-seat multiplayer only (`LocalPlayer`, `gui/LocalTurnSwap`).

## Layout
- Root: core scenes/scripts — `TitleScreen` (main scene), `Root`, `Grid`, `Tile`, `Player`, `LocalPlayer`, `GUI`
- `ships/`: `Ship.gd` base class plus one subclass per ship type; `SpecialAbility`, `PassiveAbility`, `Drawback` helper classes; `projectiles/` for attack visuals
- `gui/`: menus, ship selection, tile history, victory screen
- `audio/`, `ships/sprites/`, `gui/sprites/`, `gui/audio/`: assets

## Assets
- Mix of third-party CC-licensed assets and Ryan's own work. Every third-party asset must be credited in the README "Credits" section with author, link, and license. Flag any asset change that affects credits.
- Don't create assets (see global rules).

## Build / Export
- `build.sh` exports Linux, Windows, and macOS builds via `godot3-bin` into `builds/` (gitignored).
- `export_presets.cfg` is gitignored but present locally; it also has an HTML5 preset.

## Godot 4 Migration
Planned. Work on a dedicated branch. Approach and scope are TBD — discuss before starting. Open questions:
- Use Godot's built-in project converter as a starting point, or port by hand?
- Restructure while porting (snake_case filenames, folder layout, static typing, signal-up refactors), or port 1:1 first and restyle after?
- Add tests (GUT or gdUnit4) for game rules before or during the port to catch regressions?
- Update `.gitignore` for Godot 4 (`.godot/` replaces `.import/`), `build.sh`, and `.vscode/settings.json` (points at `godot3-bin`).
- CI for exports via GitHub Actions.

# Flotilla

Turn-based naval strategy game (Battleship meets XCOM) on hex grids. Players buy a fleet with points; ships have weapons, special/secondary abilities, passives, and drawbacks.

**The README is the design spec.** Where code and README disagree on game rules, the README is correct and the code is a bug.

## Current State
- **Godot 3.x** project (`config_version=4` in `project.godot`). Run/check it with `godot3-bin` (3.6.x). The installed `godot` is 4.x — never open this project with it outside the migration branch; it triggers project conversion.
- Headless parse check: `godot3-bin --no-window --path . --check-only -s res://<file>.gd`
- Legacy code predates the global style rules: untyped GDScript, PascalCase filenames, flat layout at repo root, `get_parent()` chains. Don't restyle 3.x code piecemeal; that happens during the port.
- Local hot-seat multiplayer only.

## Architecture
- **Board:** one 31x15 flat-top hex grid in odd-q offset coordinates. Columns 0-14 are player 0, 15 is no-man's-land, 16-30 are player 1. The opponent's columns are computed inline everywhere as `abs(player_num - 1) * 16` to `+ 15`. `Grid.get_hex_neighbor()` returns `[-1, -1]` for out of bounds, including column 15.
- **Rendering:** `Root._draw()` draws the whole board (hexes, hover, hit/miss markers, mines, labels), redrawn on every input event.
- **Turn loop:** `Root.play_game()` is a single coroutine: ship selection → placement per player → loop of (swap dialog → `new_turn()` → `get_move()`/`yield('made_move')` until no ship has AP) until a fleet is empty. Every ship action emits `made_move`. `Player` is the seam intended for future AI/network players.
- **Combat resolution:** the *defending* `Player` resolves attacks in `receive_fire()` / `receive_special()` (matched on ability name). Ships override `hit()`, `fire()`, `use_special()`, `new_turn()` etc. for passives/drawbacks and animations. Animations signal completion via `fire_animation_complete` / `special_animation_complete`; `LocalPlayer` yields on these.
- **Tile history:** each `Tile.history` entry is `[turn, "event string"]`. These strings are both the player-facing log and the data the renderer parses (e.g. `begins_with('Miss (')`) — changing wording changes behavior.
- **`Grid.get_all_hex_neighbors(x, y, n)`** returns endpoints of all n-step walks: n=1 excludes the center, n>=2 includes the center and duplicates. Callers dedupe manually.
- **AP economy:** 4 AP default. Forward 1, rotate 2, reverse 4, fire/special/secondary 2 each; one fire charge per turn (carrier 2). Cooldowns start full and tick down at turn start.
- **Coupling:** ships and players reach up the tree (`root = get_parent().get_parent()`, `root.grid`, `root.gui`). `GUI` registers itself via `get_parent().gui = self`.

## Godot 4 Port Notes
- `Vector2.angle_to_point()` reversed direction in Godot 4 — the converter does not fix this. Used for turret aiming and projectile rotation.
- Popups are `Window`s in 4 and `PopupPanel` hides on outside click; ship selection, turn swap, and victory dialogs rely on modal popups.
- `Ship.rotate()` and `TileHistory.show()` override native methods (an error by default in 4).
- `Grid`, `Tile`, `SpecialAbility`, `PassiveAbility`, `Drawback` extend bare `Object` and leak; make them `RefCounted`/`Resource`.
- Use the Compatibility renderer (Web/mobile targets).

## Assets
- Mix of third-party CC-licensed assets and Ryan's own work. Every third-party asset must be credited in the README "Credits" section with author, link, and license. Flag any asset change that affects credits.
- Don't create assets (see global rules).

## Build / Export
- `build.sh` exports Linux, Windows, and macOS builds via `godot3-bin` into `builds/` (gitignored).
- `export_presets.cfg` is gitignored but present locally; it also has an HTML5 preset.

## Task Tracking
- Trello board "Flotilla" (via the Trello MCP): https://trello.com/b/PqNY5kex/flotilla
- Lists: Maybe, Backlog, Todo, In progress, Done. Labels: Game logic, UI, Graphics, Sound, Balance.
- Bugs and feature work go on the board, not in this file.

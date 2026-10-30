# Flotilla

Turn-based naval strategy game (Battleship meets XCOM) on hex grids. Players buy a fleet with points; ships have weapons, special/secondary abilities, passives, and drawbacks.

**The README is the design spec.** Where code and README disagree on game rules, the README is correct and the code is a bug.

## Current State
- **Godot 4.7** project, Compatibility renderer (Web/mobile targets). Run/check it with `godot`.
- Headless parse check: `godot --headless --path . --check-only -s res://<file>.gd`
- Code follows the global style rules, except the coupling below (`fl-7ea`).
- Local hot-seat multiplayer only.

## Architecture
- **Board:** one 31x15 flat-top hex grid in odd-q offset coordinates, hexes as `Vector2i`. Columns 0-14 are player 0, 15 is no-man's-land, 16-30 are player 1 (`Grid.side_of()`, `Grid.columns_of()`). `Grid.get_hex_neighbor()` returns `Grid.OFF_GRID` for out of bounds, including column 15.
- **Rendering:** `Root._draw()` draws the whole board (hexes, hover, hit/miss markers, mines, labels), redrawn on every input event.
- **Turn loop:** `Root.play_game()` is a single coroutine: ship selection → placement per player → loop of (swap dialog → `new_turn()` → `get_move()`/`await made_move` until no ship has AP) until a fleet is empty. Every ship action emits `made_move`. `Player` is the seam intended for future AI/network players.
- **Combat resolution:** the *defending* `Player` resolves attacks in `receive_fire()` / `receive_special()` (matched on ability name). Ships override `hit()`, `fire()`, `use_special()`, `new_turn()` etc. for passives/drawbacks. `fire()`/`use_special()`/`use_secondary()` are coroutines that return when their animation is done (projectiles emit `done` on arrival, before the explosion); `LocalPlayer` awaits them, and the player can act again while explosions finish.
- **Tile history:** each `Tile.history` entry is `[turn, "event string"]`. These strings are both the player-facing log and the data the renderer parses (e.g. `begins_with("Miss (")`) — changing wording changes behavior.
- **`Grid.get_all_hex_neighbors(hex, n)`** returns endpoints of all n-step walks: n=1 excludes the center, n>=2 includes the center and duplicates. Callers dedupe manually.
- **AP economy:** 4 AP default. Forward 1, rotate 2, reverse 4, fire/special/secondary 2 each; one fire charge per turn (carrier 2). Cooldowns start full and tick down at turn start.
- **Coupling:** ships and players reach up the tree (`root = player.get_parent()`, `root.grid`, `root.gui`), and `GUI` registers itself via `root.gui = self`. Decoupling is `fl-7ea`.
- **Text size:** `theme.tres` (project theme) sets the default font size to 13. Smaller text uses per-node `theme_override_font_sizes/font_size`.

## Godot Notes
- Aim with `direction_to(target).angle()`, and mind which way the sprite points (turrets up, missiles left, shells and torpedoes right).
- Engine callbacks (`_ready`, `_process`, `_input`) override the parent's; subclasses must call `super()`.
- Prefer `CPUParticles2D` (works everywhere). Its defaults: `local_coords` is false and gravity is (0, 980).
- Controls block the mouse by default (`MOUSE_FILTER_STOP`). Set `MOUSE_FILTER_IGNORE` on overlays and effects (e.g. the nuke flash), or they eat clicks meant for the board.
- Create child nodes where they're attached (`_ready`, or the function that adds them), not as member defaults like `var p := AudioStreamPlayer2D.new()`. Instances that never attach them leak.
- Web exports use `variant/thread_support=false` so they run without COOP/COEP headers. Don't add threads.

## Testing
- GUT 9.7.1 (vendored in `addons/gut/`, configured by `.gutconfig.json`). Run all tests headless: `godot --headless --path . -s addons/gut/gut_cmdln.gd` (exits 1 on failure). Engine errors and `push_error` fail the running test.
- `test/unit/`: pure logic (`Grid`, `Tile`). `test/integration/`: rules exercised against an instantiated `root.tscn`.
- Files are `test_*.gd` and `extends GutTest`. Add a test for each README rule you implement or fix. Seed the RNG (`seed(n)`) in tests that depend on chance.
- `test/game_driver.gd` plays the real game through mouse input and button presses (`test_full_game.gd`, `test_gui.gd`). Hide `/root/GutRunner/GutLayer` in tests that click the board, or GUT's own window eats the clicks. The driver waits a frame before each click, as real input would.
- Run the suite after any game-logic change.
- Lint/format: `gdformat $(git ls-files '*.gd' | grep -v ^addons/)` then `gdlint` on the same files; both must be clean. Config is in `gdlintrc` (`max-public-methods` raised to 30 for `Ship`; shrink it via `fl-7ea` rather than raising it further).
- Visual checks: `test/screenshots/shots.gd` plays a scripted game in a window and saves screenshots of 15 states, to compare builds side by side. Usage is in the file's header.

## Assets
- Mix of third-party CC-licensed assets and Ryan's own work. Every third-party asset must be credited in the README "Credits" section with author, link, and license. Flag any asset change that affects credits.
- Don't create assets (see global rules).

## Build / Export
- `build.sh` exports Linux, Windows, macOS, and Web release builds into `builds/` (gitignored). Needs the export templates matching `godot --version`.
- `export_presets.cfg` is gitignored but present locally. Every preset excludes `test/*` and `addons/gut/*`.
- The version is `application/config/version` in `project.godot`; the presets leave theirs empty so they inherit it. Keep it in step with the release tag.

## Task Tracking
All tracking is in Beads (`bd`, issue prefix `fl-`). Not in this file, and not on the old Trello board (read-only archive).
- Find work: `bd ready` (unblocked), `bd list`, `bd show <id>`, `bd children <epic>`
- Track work: `bd create "Title" -t bug|feature|task|epic|decision -p 0-4 [-l label] [--parent <id>] -d "..."`, `bd update <id> -s in_progress`, `bd close <id>`, `bd dep add <issue> <depends-on>`
- Priorities: P0 blocking/soft-lock, P1 important, P2 normal, P3 later, P4 someday (usually `-s deferred`)
- Labels: `readme-spec` (code doesn't match README), `playtest-confirmed`, `balance`, `ui`, `graphics`, `sound`, `game-logic`, `release`
- Issue data lives in `.beads/embeddeddolt/` (gitignored). Backup/sync is `bd dolt push` (to `refs/dolt/data` on origin). Claude may run it without asking after changing issues. Git pushes are still Ryan's.

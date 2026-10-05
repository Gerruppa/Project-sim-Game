# Genesis Error

A game about guiding the evolution of a living planet. The planet is the main
character; the player is a catalyst who observes, intervenes and learns why
the planet behaves the way it does.

Built in Godot 4.7.2 (GDScript). The current prototype runs in a simple
window (debug visualization) or in the console:
a deterministic planetary simulation (climate, atmosphere, five species in
succession, planet personalities, crises such as droughts, ice ages,
overheating and fire seasons) with decision points, player interventions,
hints and goals.

## Play

Requirements: Windows with Git Bash and the Godot 4.7.2 console binary.

```bash
export GODOT_BIN="<path to Godot_v4.7.2-stable_win64_console.exe>"
./godot/play_window.sh          # play in a window (planet drawn live, charts, buttons)
./godot/play.sh                 # play in the console
./godot/play.sh --seed 13       # a specific planet
./godot/play.sh --load decision.json   # continue a saved game (window too)
```

Player guide (Polish): [docs/jak_grac.md](docs/jak_grac.md).

### Package for external testers

```bash
./godot/export_game.sh   # -> build/GenesisError-<date>-<commit>.zip
```

One `GenesisError.exe` (Windows x64, no install) and
`INSTRUKCJA.txt` ([docs/instrukcja_testera.txt](docs/instrukcja_testera.txt):
how to play and what to report). Needs the Godot 4.7.2 export templates
(Windows x86_64) in `%APPDATA%/Godot/export_templates/4.7.2.stable/`.
Started without options, the game opens a new-game screen (planet number
or random, character, last save). An exported game keeps saves and
chronicles in its user folder
(`%APPDATA%/Godot/app_userdata/Genesis Error/`).

## Develop

```bash
./godot/run_tests.sh            # gdUnit4 suite (~3 min)
./godot/run_simulation.sh --until decision --story   # command mode
```

| Where | What |
|---|---|
| [CLAUDE.md](CLAUDE.md) | development rules (simulation first, Fun Detector, determinism) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | overview of the code and status of the build steps |
| [docs/architecture.md](docs/architecture.md) | detailed architecture |
| [docs/gameplay.md](docs/gameplay.md) | game design decisions and their measurements |
| [docs/plan_rozwoju.md](docs/plan_rozwoju.md) | next stages, backlog, resume prompt |
| `godot/simulation/` | the simulation (no knowledge of the game or the player) |
| `godot/game/` | the game layer: planet assembly, menus, goals, hints, saves |
| `godot/ui/` | the window: planet drawing, charts, panels (Godot nodes) |
| `godot/tools/` | console entry points (`play.gd`, `run_simulation.gd`) |
| `godot/resources/` | all game data as JSON |

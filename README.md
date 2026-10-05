# Genesis Error

A game about guiding the evolution of a living planet. The planet is the main
character; the player is a catalyst who observes, intervenes and learns why
the planet behaves the way it does.

Built in Godot 4.7.2 (GDScript). The current prototype runs in the console:
a deterministic planetary simulation (climate, atmosphere, five species in
succession, planet personalities, crises such as droughts, ice ages,
overheating and fire seasons) with decision points, player interventions,
hints and goals.

## Play

Requirements: Windows with Git Bash and the Godot 4.7.2 console binary.

```bash
export GODOT_BIN="<path to Godot_v4.7.2-stable_win64_console.exe>"
./godot/play.sh                 # new planet
./godot/play.sh --seed 13       # a specific planet
./godot/play.sh --load decision.json   # continue a saved game
```

Player guide (Polish): [docs/jak_grac.md](docs/jak_grac.md).

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
| `godot/tools/` | entry points (`play.gd`, `run_simulation.gd`) |
| `godot/resources/` | all game data as JSON |

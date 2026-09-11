# Party Rush

A **3-player local co-op party platformer** inspired by Fall Guys, built with **Godot 4.5 stable**.

Race, tag, and pass the bomb across four mini-games. First player to **3 wins** takes the match!

## Requirements

- [Godot 4.5 stable](https://godotengine.org/download/archive/4.5-stable/) (or newer 4.5.x)

## How to Run

1. Open Godot 4.5 and import the `party_rush/` folder as a project.
2. Press **F5** (or click Play) to launch from the main menu.
3. Click **Start Party** — mini-games cycle automatically until someone reaches 3 wins.

## Controls

| Player | Color  | Move        | Jump   | Dash  |
|--------|--------|-------------|--------|-------|
| 1      | Red    | W A S D     | Space  | Shift |
| 2      | Blue   | Arrow Keys  | Enter  | /     |
| 3      | Yellow | I J K L     | U      | O     |

Up to **3 gamepads** are supported (pad 0 → Red, 1 → Blue, 2 → Yellow): left stick to move, **A** to jump, **B** or **X** to dash. Keyboard and gamepad work at the same time.

### Movement feel

- **Variable jump height** — tap for a short hop, hold for full height. Coyote time and jump buffering make ledge jumps forgiving.
- **Dash** — a short burst in your facing/input direction with a smoke trail and colored afterimages. One air dash per jump; short cooldown. Jump out of a grounded dash to keep momentum.
- **Squash & stretch** — players stretch on takeoff, squish on landing (scaled by fall speed), lean into runs, bob while running, and puff dust on landings and sprints.

## Mini-Games

| Game | Objective |
|------|-----------|
| **Flag Rush** | Platform to the flag — first to reach it wins |
| **Tag Frenzy** | One player is "it" and runs slightly faster — touch someone to pass the role; most tags when time runs out wins |
| **Bomb Pass** | Hot potato — bump into another player to pass the bomb before it explodes |
| **Platform Race** | Obstacle course — first across the finish line wins |

## Camera

A **fixed isometric-style camera** frames the entire map for every mini-game. Maps are compact (~24x24 units) so everyone is always on screen. The camera computes the map's bounds from the level geometry (including moving-platform travel) and positions itself at a constant pitch/yaw so the whole thing fits, re-fitting on window resize and easing between maps. Toggle `use_orthographic` on the `ArenaCamera` node for a true orthographic look.

## Falling off

Players who fall off a map are dropped back in above their spawn point with a flashing effect. Tag Frenzy and Bomb Pass are fenced with invisible walls (marked by a low curb) so nobody falls out of the action.

## Project Structure

```
party_rush/
├── project.godot
├── scenes/
│   ├── main_menu.tscn
│   ├── game.tscn
│   ├── player/player.tscn
│   └── minigames/        # Flag Rush, Tag Frenzy, Bomb Pass, Platform Race
└── scripts/
    ├── autoload/         # GameState (scores, round flow)
    ├── player/           # PlayerController
    ├── camera/           # ArenaCamera (fixed isometric, auto-framing)
    ├── minigames/        # Per-minigame logic
    └── world/            # Moving platforms, level styling
```

## License

MIT — use freely for learning and jam games.

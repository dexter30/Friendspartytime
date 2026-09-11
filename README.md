# Party Rush

A collection of **local multiplayer party games** built with **Godot 4.5 stable**. The main menu offers two games:

- **Party Rush** — a 3-player co-op party platformer inspired by Fall Guys. Race, tag, and pass the bomb across four mini-games; first player to **3 wins** takes the match.
- **Samurai Gun** — a Smash Bros-style 2D arena fighter. Pick a shape, take five stocks, and knock everyone else off the Moonlit Dojo.

## Requirements

- [Godot 4.5 stable](https://godotengine.org/download/archive/4.5-stable/) (or newer 4.5.x)

## How to Run

1. Open Godot 4.5 and import the `party_rush/` folder as a project.
2. Press **F5** (or click Play) to launch from the main menu.
3. Pick a game: **Start Party** (mini-games cycle automatically until someone reaches 3 wins) or **Enter the Dojo** (Samurai Gun character select).

## Controls

| Player | Color  | Move        | Jump   | Dash (Party Rush) | Light (Samurai Gun) | Heavy (Samurai Gun) |
|--------|--------|-------------|--------|-------------------|---------------------|---------------------|
| 1      | Red    | W A S D     | Space  | Shift             | F (or Shift)        | G                   |
| 2      | Blue   | Arrow Keys  | Enter  | /                 | /                   | .                   |
| 3      | Yellow | I J K L     | U      | O                 | O                   | P                   |

Up to **3 gamepads** are supported (pad 0 → Red, 1 → Blue, 2 → Yellow): left stick to move, **A** to jump, **B** or **X** to dash in Party Rush, **X** for light and **B** for heavy in Samurai Gun. Keyboard and gamepad work at the same time.

## Samurai Gun

A side-view platform fighter with **just two attack buttons**, five stocks each, and a Smash-style camera.

### Rules

- Every fighter starts with **5 stocks**. Damage is a rising **percent**; the higher it gets, the further you fly when hit.
- Get launched past the **blast zone** on any side and you lose a stock, then drop back in on a revival platform (hold still for a moment or move to leave it — you're intangible for a beat either way).
- **Last fighter with stocks wins.** A "GAME!" slow-mo leads into the results screen: Jump to rematch, Heavy to return to character select, Esc for the main menu.

### Fighting

- **Movement:** run, full jump or short hop (tap), **double jump**, **fast fall** (hold down in the air), drop through the floating platforms by tapping down while standing on one.
- **Light — katana.** Fast slashes. On the ground, neutral lights chain into a **3-hit combo** (the third slash launches). Hold **up** for a rising slash, **down** for a low sweep. In the air: a wide aerial slash, or hold **down** for a downward stab that **spikes** opponents.
- **Heavy — gun.** A short-range blast with a wind-up. **Hold to charge** for up to 55% more damage/knockback and a longer shot. Firing kicks you backwards. Hold **up** to shoot upward, **down** in the air to shoot downward — the recoil gives you a **gun jump** for recovery and the shot spikes anyone below. On the ground, down-heavy fires into the floor for a **shockwave** that hits both sides.
- **Feel:** hitstop on every hit, hit sparks, damage numbers, camera shake, squash & stretch, launch trails, revival flashing, and KO bursts.

### Fighters

All fighters are shapes — the colour, the eyes, and the name are what set them apart, plus light weight/speed/jump tweaks.

| Fighter | Shape | Look | Style |
|---------|-------|------|-------|
| **Ronin Rhombus** | Diamond, crimson | Slanted angry eyes | All-rounder |
| **Sensei Square** | Square, indigo | Half-closed sleepy eyes | Heavyweight, slow, hard to launch |
| **Shuriken Tri** | Triangle, jade | Wide alert eyes | Fastest, lightest |
| **Daimyo Dot** | Circle, gold | Tiny dot eyes and a monocle | Floaty, high jump |
| **Hexa Hanzo** | Hexagon, violet | One big cyan cyclops eye | Balanced |
| **Penta Petal** | Pentagon, sakura pink | Big sparkly anime eyes with lashes | Light, highest jump |
| **Star Shogun** | Star, blazing orange | Star-shaped pupils | Heavy hitter |
| **Kappa Capsule** | Capsule, teal | Round drowsy eyes | Quick and steady |

### Character select

Each player presses **Jump** to join, moves their coloured cursor with their movement keys, and presses **Jump** to lock in (**Heavy** to back out). Once everyone who joined is locked in, any ready player presses **Jump** to start. If only one player joins, a **CPU opponent** fills in with a random fighter.

### Camera

The arena uses a **Smash-style dynamic camera**: it pans to the midpoint of all living fighters and zooms in or out to keep everyone in frame, clamped so the blast zones stay just off-screen. Big hits and KOs shake it.

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
│   ├── minigames/        # Flag Rush, Tag Frenzy, Bomb Pass, Platform Race
│   └── samurai_gun/      # character_select, arena, fighter
└── scripts/
    ├── autoload/         # GameState (scores, round flow), SamuraiGunState (match setup)
    ├── player/           # PlayerController
    ├── camera/           # ArenaCamera (fixed isometric, auto-framing)
    ├── minigames/        # Per-minigame logic
    ├── world/            # Moving platforms, level styling
    └── samurai_gun/      # Fighter, moves, roster, visuals, camera, stage, HUD, CPU brain
```

## License

MIT — use freely for learning and jam games.

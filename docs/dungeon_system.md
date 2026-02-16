# Dungeon System — Architecture & Usage Guide

## Overview

The dungeon system transforms BraveHeart from a Vampire-Survivors-style arena
into a **Binding of Isaac–style room-based dungeon crawler**.  The player
explores a procedurally generated grid of rooms, each connected by doors.
Enemies spawn when a room is first entered, doors lock until every enemy is
dead, and the full layout is persisted so the player can backtrack.

---

## Architecture at a Glance

```
┌──────────────────────┐        ┌─────────────────────┐
│   DungeonManager     │◄──────►│     RoomManager     │
│  (autoload / graph)  │        │ (autoload / runtime) │
│                      │        │                      │
│  • generate_dungeon()│        │  • enter_room()      │
│  • dungeon_map{}     │        │  • transition_to_room()│
│  • mark_visited()    │        │  • _spawn_enemies()  │
│  • mark_cleared()    │        │  • _lock/_unlock_doors│
└──────────────────────┘        └──────────┬──────────┘
                                           │ loads
                                           ▼
                                ┌──────────────────────┐
                                │   Room Scene (.tscn)  │
                                │  root: RoomTemplate   │
                                │  children:            │
                                │   └─ SpawnPoints/     │
                                │       ├─ Marker2D     │
                                │       ├─ Marker2D     │
                                │       └─ …            │
                                └──────────────────────┘
                                           │ placed by RoomManager
                                           ▼
                                ┌──────────────────────┐
                                │   DoorController      │
                                │   (per direction)     │
                                │  • lock() / unlock()  │
                                │  • player_entered_door│
                                └──────────────────────┘
```

### Key Scripts

| File | Role |
|------|------|
| `scripts/dungeon/DungeonManager.gd` | **Autoload.** Generates and stores the dungeon graph. Pure data — no scene tree manipulation. |
| `scripts/dungeon/RoomManager.gd` | **Autoload.** Loads room scenes, places the player, builds walls, spawns enemies, manages door lock/unlock, handles room transitions with fade. |
| `scripts/dungeon/RoomTemplate.gd` | **Attached to every room scene root.** Exports metadata (difficulty, tags). Provides `build_walls()`, `draw_floor()`, `draw_wall_visuals()` helpers that RoomManager calls. |
| `scripts/dungeon/DoorController.gd` | **Instantiated per-door by RoomManager.** Auto-positions itself on the correct wall. Contains an `Area2D` trigger and a `StaticBody2D` blocker. |

---

## How Dungeon Generation Works

1. **Pool scan** — On `_ready()`, `DungeonManager` scans `res://scenes/rooms/`
   for `.tscn` files that are *not* the `StartRoom`.  Every file found is added
   to `_room_pool`.

2. **Graph construction** — `generate_dungeon(size)`:
   - Place `StartRoom` at grid position `(0, 0)`.
   - Maintain a *frontier* list of rooms that still have empty neighbours.
   - On each iteration pick a random frontier room, pick a random free
     direction, place a new room from the pool, and record bidirectional
     connections.
   - Optionally (~40 % chance) also connect to other existing adjacent rooms —
     this creates loops so the player can backtrack via alternative routes.
   - Continue until `dungeon_size` rooms have been placed or no room can
     expand.

3. **Result** — `dungeon_map` is a `Dictionary[Vector2i → RoomInfo]` that the
   rest of the game reads.

### RoomInfo Data Class

```gdscript
class RoomInfo:
    var scene_path: String       # e.g. "res://scenes/rooms/CombatRoom2.tscn"
    var grid_pos: Vector2i       # position on the dungeon grid
    var connections: Dictionary   # "north" → Vector2i, "east" → Vector2i, …
    var is_visited: bool
    var is_cleared: bool
    var is_start: bool
    var is_boss_room: bool       # true for the level's boss encounter room
    var difficulty: int
    var tags: Array[String]
```

---

## Room Lifecycle

### Entering a room (`RoomManager.enter_room`)

1. Tear down the previous room instance (enemies, doors, node).
2. `load()` and `instantiate()` the new room scene into `RoomContainer`.
3. Call the room template helpers to draw the floor, wall visuals, and
   collision walls (with gaps for connected directions).
4. Instantiate `DoorController` nodes for every connected direction.
5. Place the player at the correct entry offset.
6. Centre the camera on the room.
7. **First visit & not start room →** lock doors, spawn enemies.
8. **Revisit or start room →** unlock doors, skip spawning.

### Transition (`RoomManager.transition_to_room`)

1. Fade the screen to black (0.15 s).
2. Call `enter_room(target_grid_pos, opposite_direction)`.
3. Fade back in (0.15 s).

### Room Clearing

- Each spawned enemy is tracked in `_active_enemies`.
- When an enemy's `tree_exiting` signal fires, it is removed from the list.
- When the list empties → `mark_cleared()`, `_unlock_doors()`,
  `room_cleared` signal.

---

## Door System

Each door is a `DoorController` node with:

| Child | Purpose |
|-------|---------|
| `DoorArea` (Area2D, mask = player) | Detects the player stepping through. |
| `DoorBlocker` (StaticBody2D, layer = 1) | Physically blocks the player when locked. |
| `DoorVisual` (ColorRect) | Red when locked, green when open. |

**Lock** → enable blocker collision, red visual.
**Unlock** → disable blocker collision, green visual.

When the player's body enters `DoorArea` while unlocked, the controller emits
`player_entered_door(direction)` which RoomManager picks up to start the
transition.

---

## How to Add a New Room

1. **Create a scene** — `scenes/rooms/MyNewRoom.tscn` with a `Node2D` root.
2. **Attach `RoomTemplate.gd`** to the root (or a script that extends it).
3. **Set exports** — `difficulty`, `tags` (e.g. `["combat", "hard"]`).
4. **Add spawn points** — Create a child `Node2D` named `SpawnPoints` and put
   `Marker2D` children inside it, positioned where enemies should appear.
5. **Add decorations** (optional) — Any extra child nodes (sprites, obstacles,
   etc.) are fine.  They'll be instantiated automatically.
6. **Save** — The file must live in `res://scenes/rooms/` and end in `.tscn`.
   It will be **automatically discovered** on the next dungeon generation; no
   registration code needed.

### Room Template Exports

```gdscript
@export var difficulty: int = 0            # 0 = easy, higher = harder
@export var tags: PackedStringArray = []   # free-form tags
@export var room_width: int = 1152         # keep consistent for MVP
@export var room_height: int = 648
@export var wall_thickness: float = 32.0
@export var door_gap: float = 96.0
```

> **Tip:** For MVP all rooms should use the same `room_width` / `room_height`.
> Variable-size rooms are possible later by extending the wall-building logic.

---

## Persisted Dungeon Memory

The dungeon is generated once per run.  `DungeonManager.dungeon_map` stores:

- **`is_visited`** — set `true` the first time the player enters.
- **`is_cleared`** — set `true` when all enemies in the room are dead.

When the player backtracks to a cleared room:
- Enemies are **not** respawned.
- Doors are **unlocked** immediately.

This state is held in memory for the duration of the run.  On restart
(`reload_current_scene`), everything is regenerated.

---

## Integration with Existing Systems

| System | Change |
|--------|--------|
| **GameManager** | Calls `DungeonManager.reset()` and `RoomManager.reset()` in `start_game()`. No longer calls `EnemySpawner.start_spawning()`. |
| **EnemySpawner** | Gutted — now a thin compatibility stub. Room-based spawning is in `RoomManager`. |
| **BossManager** | Spawns bosses inside the current room and registers them with `RoomManager._active_enemies` so doors stay locked. |
| **PlayerController** | Added `add_to_group("player")` and `collision_mask = 1` so the player collides with room walls and is detectable by doors. |
| **HUD** | New `RoomLabel` shows current grid position and cleared status.  Listens to `RoomManager.doors_locked/unlocked` to tint the label. |
| **Game.tscn** | Removed old `GroundTileMap` and player-attached `Camera2D`. Added `RoomContainer`, standalone `RoomCamera`, and `TransitionLayer` with a `ColorRect` for fades. |

---

## Dungeon Level Progression (Binding of Isaac–style)

The dungeon now supports **level-based progression**. Each level is a full
dungeon floor with a boss room. Defeating the boss opens a trapdoor to the
next level.

### How It Works

```
Level 1  →  explore rooms  →  find boss room  →  defeat boss
                                                     │
          ┌──────────────────────────────────────────┘
          ▼
   trapdoor spawns in boss room center
          │
          ▼
   player enters trapdoor
          │
          ▼
Level 2  →  new dungeon generated (bigger, harder)  →  ...
```

### Dungeon Size Scaling

Each level generates a larger dungeon:

```
dungeon_rooms = dungeon_size + (dungeon_level - 1) × size_growth_per_level
```

| Level | Rooms (defaults) |
|-------|-----------------|
| 1     | 12              |
| 2     | 15              |
| 3     | 18              |
| 4     | 21              |
| …     | +3 per level    |

Configurable via exports on `DungeonManager`:
- `dungeon_size` — base room count (default 12)
- `size_growth_per_level` — rooms added per level (default 3)

### Boss Room

- Automatically placed at the **farthest room from start** (Manhattan distance).
- Uses the `BossRoom.tscn` scene (excluded from the random room pool).
- `RoomInfo.is_boss_room = true` so RoomManager knows to spawn a boss.
- Boss is scaled by dungeon level:
  - Health: `base × (1.0 + (level - 1) × 0.5)`
  - Damage: `base × (1.0 + (level - 1) × 0.3)`
  - Speed:  `base × (1.0 + (level - 1) × 0.1)`

### Trapdoor

After the boss is defeated in the boss room:
1. Doors unlock as normal.
2. A **Trapdoor** spawns at room center (dark square with golden border).
3. When the player walks into the trapdoor:
   - `GameManager.advance_dungeon_level()` increments the level counter.
   - The current dungeon is cleaned up.
   - A new dungeon is generated with the next level's size.
   - The player enters the new start room.

### Difficulty Scaling by Level

All enemies in the dungeon get a base difficulty boost from the dungeon level:

```
room_difficulty = manhattan_distance_from_start + (dungeon_level - 1)
```

This means on level 1 the start-adjacent rooms have difficulty 1, but on
level 3 those same rooms have difficulty 3. The existing per-room scaling
(health ×1.25 per difficulty, speed ×1.08 per difficulty) stacks with this.

### Key Signals

| Signal | Emitter | When |
|--------|---------|------|
| `RoomManager.boss_room_cleared(grid_pos)` | RoomManager | Boss killed in boss room |
| `RoomManager.trapdoor_entered` | RoomManager | Player steps on trapdoor |
| `GameManager.dungeon_level_changed(level)` | GameManager | Level counter incremented |

### Level Progression Flow (Game.gd)

```gdscript
func _on_trapdoor_entered():
    GameManager.advance_dungeon_level()
    GameManager.cleanup_game()
    RoomManager.reset()
    DungeonManager.generate_dungeon()
    # fade transition...
    RoomManager.enter_room(DungeonManager.start_pos, "center")
```

The player keeps all upgrades, XP, and stats across levels. Only the dungeon
layout and enemies are regenerated.

---

## Future Extensions

The architecture is designed to grow:

- **Item / treasure rooms** — Tag `"treasure"`, spawn a pickup instead of
  enemies, door is always open.
- **Shop rooms** — Same pattern, different content.
- **Minimap** — Iterate `DungeonManager.dungeon_map`, draw visited rooms as
  coloured squares on a CanvasLayer overlay.
- **Variable room sizes** — Extend `RoomTemplate` with different `room_width /
  room_height`, update `RoomManager` to read them and adjust camera/walls.
- **Tilemapped rooms** — Replace `draw_floor` / `draw_wall_visuals` with
  actual TileMap layers inside the room scene.
- **Persistent room state** — Store enemy positions, destructible states, etc.
  in `RoomInfo` for mid-fight backtracking.
- **Level-specific enemy types** — Introduce new enemy scenes per dungeon
  level or difficulty tier.
- **Inter-level shops / rest rooms** — Show a special screen between levels
  before generating the next dungeon.

---

## File Inventory

```
scripts/dungeon/
├── DungeonManager.gd      # Autoload — graph gen, level tracking & state
├── RoomManager.gd         # Autoload — room loading, boss/trapdoor handling
├── RoomTemplate.gd        # class_name RoomTemplate — room base script
├── DoorController.gd      # class_name DoorController — door behaviour
└── Trapdoor.gd            # class_name Trapdoor — level transition trigger

scenes/rooms/
├── Door.tscn              # Door prefab (loaded by RoomManager)
├── StartRoom.tscn         # Empty starting room
├── BossRoom.tscn          # Boss encounter room (auto-placed, not in pool)
├── CombatRoom1.tscn       # 5 spawn points, difficulty 1
├── CombatRoom2.tscn       # 7 spawn points, difficulty 1
└── CombatRoom3.tscn       # 10 spawn points, difficulty 2

docs/
└── dungeon_system.md      # This file
```

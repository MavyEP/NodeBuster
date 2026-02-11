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

## Future Extensions

The architecture is designed to grow:

- **Boss rooms** — Tag a room `"boss"`, place it at the end of a branch,
  spawn a boss instead of regular enemies.
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

---

## File Inventory

```
scripts/dungeon/
├── DungeonManager.gd      # Autoload — graph gen & state
├── RoomManager.gd         # Autoload — room loading & gameplay
├── RoomTemplate.gd        # class_name RoomTemplate — room base script
└── DoorController.gd      # class_name DoorController — door behaviour

scenes/rooms/
├── Door.tscn              # Door prefab (loaded by RoomManager)
├── StartRoom.tscn         # Empty starting room
├── CombatRoom1.tscn       # 5 spawn points, difficulty 1
├── CombatRoom2.tscn       # 7 spawn points, difficulty 1
└── CombatRoom3.tscn       # 10 spawn points, difficulty 2

docs/
└── dungeon_system.md      # This file
```

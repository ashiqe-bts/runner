# Product Requirements Document

## True 3D Endless Runner Built With Flutter

**Version:** 2.0
**Platforms:** Android and iOS
**Orientation:** Portrait
**Language:** Dart
**Application Framework:** Flutter
**3D Rendering:** flutter_scene
**Game Type:** True 3D endless runner
**Networking:** Offline-first
**Backend:** None required for V1

---

# 1. Product Vision

Create a polished **true 3D endless-running mobile game** inspired by the gameplay category established by games such as Temple Run and Subway Surfers, while using completely original:

* characters;
* environments;
* obstacles;
* visual identity;
* progression;
* music;
* sounds;
* world design;
* animations.

The game must be developed entirely using:

**Flutter + Dart + Flutter/Dart packages.**

It must not use:

* Unity;
* Unreal Engine;
* Godot;
* another standalone game engine.

The player controls a fully animated 3D character running through an endlessly generated 3D environment.

The core experience is:

**Run → dodge → jump → slide → collect → survive → accelerate → crash → upgrade → run again.**

---

# 2. True 3D Requirement

This game must NOT simulate depth using 2D sprite scaling.

The world must exist in real three-dimensional coordinates:

```text
X = horizontal position
Y = vertical position
Z = forward/backward depth
```

The game must contain:

* 3D character models;
* 3D obstacle models;
* 3D environments;
* perspective camera;
* real model transforms;
* XYZ positioning;
* rotation;
* scaling;
* depth;
* 3D collision volumes;
* lighting;
* shadows where practical;
* skeletal character animation;
* 3D track geometry.

Example:

```text
              +Y
               ↑
               |
               |
-X  ←──────── Player ────────→ +X
              /
             /
           +Z
```

---

# 3. Technical Direction

Recommended stack:

```text
Flutter
│
├── Flutter UI
│
├── Dart game systems
│
└── flutter_scene
     ├── 3D renderer
     ├── Scene graph
     ├── Perspective camera
     ├── glTF / GLB loading
     ├── Materials
     ├── Lighting
     ├── Skeletal animation
     └── 3D transforms
```

`flutter_scene` provides a Flutter-oriented 3D scene system with perspective cameras, glTF loading and PBR materials.

---

# 4. Why flutter_scene Instead of Flame 3D

`flame_3d` is an interesting option and integrates naturally with Flame, but its current documentation labels the project experimental and warns that APIs may break and that it should not yet be treated as production-ready.

For this project, use:

```yaml
flutter_scene
vector_math
shared_preferences
```

Then introduce additional packages only where required.

Do not over-depend on packages.

---

# 5. Rendering Architecture

The game should contain one primary 3D scene.

Conceptually:

```text
RunnerGame
│
├── Scene
│
├── Camera
│
├── Lighting
│
├── Environment
│
├── TrackManager
│
├── Player
│
├── ObstacleManager
│
├── CollectibleManager
│
├── PowerUpManager
└── EffectsManager
```

Normal application UI remains Flutter widgets.

Example:

```text
Flutter
├── Home
├── Shop
├── Character selection
├── Missions
├── Settings
│
└── GameScreen
      ├── 3D SceneView
      └── Flutter HUD overlay
```

---

# 6. 3D Asset Format

Primary 3D asset format:

```text
.glb
```

or:

```text
.gltf
```

Prefer `.glb` where possible because models, animations and related asset data can be packaged conveniently.

3D assets include:

```text
characters/
obstacles/
track/
environment/
props/
powerups/
collectibles/
```

Example:

```text
assets/
├── models/
│   ├── characters/
│   │   └── runner.glb
│   ├── track/
│   ├── obstacles/
│   ├── environment/
│   └── collectibles/
│
├── textures/
├── audio/
└── ui/
```

---

# 7. Character Model

The main runner must be a rigged 3D model.

Required animation clips:

```text
Idle
Run
Jump
Fall
Land
Slide
Hit
Death
```

Recommended additional animations:

```text
MoveLeft
MoveRight
Stumble
PowerUp
Victory
```

Animations should be skeletal rather than hundreds of individual model files.

---

# 8. Coordinate System

Standardize coordinates early.

Recommended:

```text
X = lanes
Y = height
Z = forward direction
```

Example:

```text
Left lane   X = -2

Center lane X = 0

Right lane  X = 2
```

Player:

```text
Vector3(
  laneX,
  currentHeight,
  playerZ,
)
```

Do not scatter coordinate values throughout the source code.

Store them in configuration.

---

# 9. Player Movement

The player automatically moves forward.

There are four primary commands:

```text
Swipe Left
Swipe Right
Swipe Up
Swipe Down
```

Corresponding actions:

```text
Left  → lane change left
Right → lane change right
Up    → jump
Down  → slide
```

---

# 10. Lane System

Initial game:

**3 lanes**

```text
-1 = left

0 = center

1 = right
```

The player moves smoothly between lane centers.

Never teleport instantly.

Example:

```text
currentX = 0

Swipe left

targetX = -2

interpolate:

0
-0.4
-0.9
-1.5
-2
```

Approximate transition time:

```text
120–220 ms
```

Tune through playtesting.

---

# 11. Forward Movement Strategy

For an endless game, avoid allowing the player Z coordinate to grow indefinitely.

Instead:

```text
Player stays near Z = 0

World moves toward player
```

Example:

```text
Player
Z = 0

Obstacle
Z = 80

↓

70

↓

50

↓

20

↓

0

↓

-20 → recycle
```

This makes endless generation easier and prevents enormous world coordinates.

---

# 12. Player State Machine

Recommended states:

```text
idle
running
laneChanging
jumping
falling
landing
sliding
stumbling
protected
dead
reviving
paused
```

Example:

```text
RUNNING
   ↓
JUMPING
   ↓
FALLING
   ↓
LANDING
   ↓
RUNNING
```

State management must prevent conflicting actions.

---

# 13. Jump Physics

Jumping operates in real Y space.

Example:

```text
Velocity Y
+
Gravity
+
Ground detection
```

Concept:

```dart
verticalVelocity += gravity * deltaTime;

playerY += verticalVelocity * deltaTime;
```

When:

```text
playerY <= groundY
```

the player lands.

The game does not require hyper-realistic physics.

Responsiveness is more important than realism.

---

# 14. Slide System

Sliding should:

* play slide animation;
* shorten player's collision capsule;
* maintain forward motion;
* last a defined duration.

Example:

```text
Normal collider

      O
     /|\
     / \
   [     ]


Slide collider

   O____
  [____]
```

When slide finishes:

```text
slide collider
→ normal collider
```

---

# 15. Camera System

Use a real **PerspectiveCamera**.

Camera position approximately:

```text
Player
  ↑

Camera
behind
+
above
```

Concept:

```text
Camera position:
(0, 4, -7)

Look toward:
(0, 1.5, 10)
```

Exact coordinates depend on the models.

Camera should:

* follow player lane movement subtly;
* maintain obstacle visibility;
* avoid aggressive movement;
* keep the player readable.

---

# 16. Camera Effects

Optional effects:

### Speed FOV

At higher speed:

```text
FOV increases slightly
```

creating stronger sensation of speed.

### Collision Shake

Small temporary shake.

### Power-Up Effects

For example:

```text
speed boost
→ slight FOV expansion
```

Avoid excessive camera movement.

---

# 17. Lighting

The scene should use intentionally designed lighting.

Recommended starting setup:

```text
Directional light
+
ambient/environment lighting
```

Potential additions:

```text
point lights
spotlights
emissive materials
environment maps
```

The objective is not photorealism.

Mobile performance takes priority.

---

# 18. Materials

Prefer optimized materials.

Use PBR materials selectively for:

* player;
* major environment pieces;
* important obstacles.

Avoid:

* excessive transparent materials;
* unnecessarily large textures;
* complex shaders everywhere.

Visual quality must be balanced against mobile GPU performance.

---

# 19. Track System

The world is composed from reusable **3D track chunks**.

Example:

```text
[Chunk A]
[Chunk B]
[Chunk C]
[Chunk D]
[Chunk E]
```

Each chunk may contain:

```text
road
walls
buildings
vegetation
obstacles
coins
lights
props
power-ups
```

When a chunk passes behind the camera:

```text
remove/recycle
→ reposition ahead
→ configure new content
```

---

# 20. Endless Chunk Generation

At any moment:

```text
Behind player
    ↓
[old]

[player]

[active]
[active]
[active]
[next]
[next]
    ↑
Ahead
```

Maintain several chunks in front of the player so no generation is visible.

Example:

```text
5–10 active chunks
```

depending on chunk size.

---

# 21. Chunk Data

Example conceptual model:

```dart
class TrackChunkDefinition {
  final String id;

  final double length;

  final int difficulty;

  final List<ObstacleSpawn> obstacles;

  final List<CoinSpawn> coins;

  final List<PowerUpSpawn> powerUps;

  final List<PropSpawn> props;
}
```

Do not hard-code every chunk into rendering code.

Use data-driven definitions.

---

# 22. Procedural Generation

Generation must be controlled rather than completely random.

Use:

```text
Difficulty Manager
        ↓
Pattern Selector
        ↓
Chunk Generator
        ↓
Validity Check
        ↓
Spawn
```

Patterns may contain combinations such as:

```text
LEFT blocked

CENTER safe

RIGHT coins
```

or:

```text
LEFT high obstacle

CENTER jump obstacle

RIGHT safe
```

---

# 23. Fairness Validator

Before accepting generated content, ensure at least one survivable route exists.

The generator must reject patterns like:

```text
LEFT   = impossible
CENTER = impossible
RIGHT  = impossible
```

unless a valid jump/slide action makes the section survivable.

The generator should understand:

```text
lane
jump
slide
reaction time
speed
```

---

# 24. Seeded Generation

Use seeded randomness.

Example:

```dart
Random(928471);
```

Then a bug can be reproduced:

```text
Seed: 928471
Distance: 2,814 m
Chunk: 158
```

This will be extremely valuable during testing.

---

# 25. Difficulty Progression

Difficulty increases based on:

```text
distance
+
time alive
+
current speed
```

Difficulty affects:

* runner speed;
* obstacle density;
* obstacle combinations;
* moving obstacles;
* reaction distance;
* coin patterns.

Example:

```text
0–500m
Beginner

500–1500m
Normal

1500–3000m
Hard

3000m+
Expert
```

Exact numbers require balancing.

---

# 26. Speed System

Example:

```text
Initial:

8 m/s

↓

10 m/s

↓

12 m/s

↓

14 m/s

↓

Maximum target
```

Acceleration must be gradual.

Never increase difficulty so quickly that failure feels arbitrary.

---

# 27. 3D Obstacles

MVP obstacle categories:

### Solid blocker

Requires lane change.

### Low barrier

Requires jump.

### High barrier

Requires slide.

### Moving obstacle

Moves between lanes.

### Gap

Requires jump.

### Wide obstacle

Blocks multiple lanes.

Eventually add more environment-specific hazards.

---

# 28. 3D Collision

Use simple collision shapes rather than detailed mesh collision whenever possible.

Preferred:

```text
Capsule
Box
Sphere
```

Player:

```text
Capsule collider
```

Obstacles:

```text
Box collider
```

Coins:

```text
Sphere / trigger
```

Power-ups:

```text
Sphere / trigger
```

Simple colliders are significantly easier to optimize.

---

# 29. Physics Strategy

An endless runner does NOT require realistic rigid-body physics everywhere.

The player should primarily be **kinematic**.

That means we control movement directly.

For example:

```text
lane movement
jump
slide
forward speed
```

should be deterministic.

Use physics mainly for:

```text
collision detection
ground checks
trigger detection
raycasting
```

not for allowing the physics engine to decide player movement.

`flutter_scene` exposes a physics abstraction and includes a basic pure-Dart simulation suitable for queries, triggers and kinematic-style gameplay.

---

# 30. Advanced Physics Option

If the game later needs full 3D rigid-body simulation, `flutter_scene_rapier` provides Rapier integration including:

* rigid bodies;
* colliders;
* collision events;
* raycasts;
* shape casts;
* character-controller functionality.

However, its current package documentation labels it experimental.

Therefore:

**Do not make advanced Rapier physics a core MVP dependency unless testing proves it necessary.**

For the first endless-runner version, custom kinematic movement + simple collision testing is preferable.

---

# 31. Coin System

Coins are real 3D objects.

They may:

* rotate;
* float;
* animate vertically;
* emit subtle light/effects.

Patterns:

```text
straight line

arc

zig-zag

lane switch

jump arc

slide path
```

Coin placement also communicates how the player should move.

---

# 32. Magnet Power-Up

When active, nearby coins move toward the player.

Concept:

```text
distance < magnetRadius
```

then:

```text
coin.position
→ interpolate toward player.position
```

Do not instantly teleport coins.

The attraction animation makes the power-up satisfying.

---

# 33. Core Power-Ups

V1:

### Magnet

Attract coins.

### Shield

Protect from one collision.

### Score Multiplier

Example:

```text
2x score
```

### Coin Multiplier

Example:

```text
2x coins
```

Future:

```text
super jump
speed boost
flight
slow motion
invulnerability
```

---

# 34. Scoring

Base score should derive primarily from distance.

Concept:

```text
score =
distance × scoreMultiplier
+
bonuses
```

Track separately:

```text
score
distance
coins
high score
maximum distance
```

---

# 35. Game Over

Sequence:

```text
Collision
↓
impact animation
↓
camera/effect
↓
stop gameplay
↓
death animation
↓
Game Over UI
```

Show:

```text
Score

High Score

Distance

Coins

Mission Progress
```

Primary button:

**RUN AGAIN**

---

# 36. Revival

Optional V1 feature.

Flow:

```text
Death

↓

Revive?

↓

3
2
1

↓

temporary invulnerability

↓

continue
```

Immediately after revival:

* clear dangerous nearby obstacles;
* provide safe spawn space;
* grant short invulnerability.

---

# 37. Characters

Character data:

```text
ID
Name
GLB model
Animations
Price
Unlock status
Selected status
Ability
```

MVP:

```text
1 default character
+
2–4 unlockable characters
```

Initially characters may differ only visually.

---

# 38. Environment

Start with **one excellent environment**.

Do not make five mediocre environments.

Example concept:

**Futuristic elevated city transit network**

Could include:

```text
roads
bridges
tunnels
rooftops
trains
holograms
construction zones
neon districts
```

But the final theme should establish its own visual identity.

---

# 39. Environment Variation

Even one world can contain sub-biomes:

```text
City streets

↓

Tunnel

↓

Bridge

↓

Station

↓

Rooftops

↓

Industrial sector
```

This reduces visual repetition.

---

# 40. Level Streaming

Never load the entire environment.

Load/reuse only nearby content.

Concept:

```text
Behind
2 chunks

Current
1 chunk

Ahead
6 chunks
```

As player runs:

```text
old chunk
→ reset
→ move to front
→ populate new pattern
```

---

# 41. Object Pooling

Pool frequently reused objects:

```text
coins
obstacles
power-ups
particles
track chunks
decorations
```

Avoid:

```text
create
destroy
create
destroy
```

during every second of gameplay.

Prefer:

```text
activate
deactivate
reset
reuse
```

---

# 42. 3D Optimization

Performance is one of the biggest technical risks.

Targets:

```text
60 FPS
```

Primary frame budget:

```text
~16.67 ms
```

Optimize:

* triangle counts;
* draw calls;
* material count;
* texture sizes;
* skeletal complexity;
* shadow quality;
* active objects;
* particle count.

---

# 43. Model Budgets

Establish budgets during prototyping.

For example:

### Main Character

Moderate polygon count.

### Nearby obstacles

Moderate.

### Background objects

Low-poly.

### Very distant scenery

Very low-poly.

Use **LOD — Level of Detail** where practical.

Example:

```text
Near building
→ detailed model

Medium
→ reduced model

Far
→ very simplified model
```

---

# 44. Texture Strategy

Recommended starting limits:

```text
Character:
1024–2048

Important obstacles:
512–1024

Background props:
256–1024
```

Do not automatically use 4K textures.

Mobile screens rarely justify them for this style of game.

---

# 45. Shadows

Shadows are visually useful but expensive.

Prioritize:

* player shadow;
* important obstacle shadows.

Consider:

```text
blob shadow
```

for some objects rather than full dynamic shadows.

Benchmark physical devices before enabling expensive shadow settings broadly.

---

# 46. Animation Performance

Avoid animating dozens of unnecessary skeletons simultaneously.

Character:

```text
skeletal animation
```

Nearby dynamic obstacle:

```text
animation when necessary
```

Background crowds:

prefer:

```text
simplified animation
```

or avoid them entirely in MVP.

---

# 47. Flutter HUD

Gameplay UI should remain standard Flutter.

Overlay over 3D scene:

```text
┌──────────────────────────┐
│ SCORE       DISTANCE  🪙 │
│                          │
│                          │
│        3D GAME           │
│                          │
│                          │
│           ⏸              │
└──────────────────────────┘
```

Do not render ordinary buttons as 3D objects unnecessarily.

Flutter is excellent for:

```text
menus
buttons
settings
HUD
shop
mission UI
dialogs
```

---

# 48. Screens

Required:

```text
Splash

Loading

Home

Character Selection

Gameplay

Pause

Game Over

Missions

Settings
```

Future:

```text
Shop
Achievements
Daily Rewards
Events
```

---

# 49. Tutorial

Interactive first-run tutorial:

```text
SWIPE LEFT
↓
player moves

SWIPE RIGHT
↓
player moves

SWIPE UP
↓
player jumps

SWIPE DOWN
↓
player slides

COLLECT COINS
↓
normal gameplay begins
```

Avoid lengthy instructions.

---

# 50. Audio

Required:

```text
background music

running sounds

jump

landing

slide

coin

power-up

collision

UI buttons

game over
```

Audio must be preloaded where practical.

Never stall the game while loading a common sound.

---

# 51. Haptic Feedback

Examples:

```text
Coin
→ very light / none

Power-up
→ light

Collision
→ strong

Shield broken
→ medium
```

Provide:

```text
Haptics On / Off
```

---

# 52. Progression

Core progression loop:

```text
RUN

↓

Earn Coins

↓

Complete Missions

↓

Unlock Character

↓

Upgrade Power-ups

↓

Improve Multiplier

↓

RUN AGAIN
```

Progression must complement skill, not replace it.

---

# 53. Missions

Examples:

```text
Run 1,000 meters

Collect 500 coins

Jump over 30 barriers

Slide 20 times

Use 3 magnets

Reach 25,000 score

Run 750m without collision
```

Maintain approximately:

```text
3 active missions
```

---

# 54. Persistence

Save locally:

```text
highScore
maximumDistance
coins
characters
selectedCharacter
missions
settings
tutorialCompleted
powerUpLevels
```

Use repository abstraction:

```text
ProgressRepository

SettingsRepository

CharacterRepository
```

Do not let UI directly manipulate storage.

---

# 55. Main Architecture

```text
lib/
│
├── main.dart
│
├── app/
│
├── game/
│   │
│   ├── runner_game.dart
│   │
│   ├── scene/
│   │   ├── game_scene.dart
│   │   ├── lighting.dart
│   │   └── camera_controller.dart
│   │
│   ├── player/
│   │   ├── player.dart
│   │   ├── player_controller.dart
│   │   ├── player_state.dart
│   │   └── player_animation.dart
│   │
│   ├── track/
│   │   ├── track_manager.dart
│   │   ├── track_chunk.dart
│   │   ├── chunk_definition.dart
│   │   └── chunk_generator.dart
│   │
│   ├── obstacles/
│   │
│   ├── collectibles/
│   │
│   ├── powerups/
│   │
│   ├── collision/
│   │
│   ├── difficulty/
│   │
│   └── config/
│
├── features/
│   ├── home/
│   ├── missions/
│   ├── characters/
│   ├── settings/
│   └── game_over/
│
├── data/
│
└── shared/
```

---

# 56. Game Loop

Central loop:

```text
Frame Start

↓

Read Inputs

↓

Update Player

↓

Update Difficulty

↓

Move World

↓

Update Obstacles

↓

Update Coins

↓

Detect Collisions

↓

Update Score

↓

Recycle Chunks

↓

Update Camera

↓

Render 3D Scene

↓

Flutter HUD
```

Use `deltaTime`.

Never assume exactly 60 frames per second.

Incorrect:

```dart
position.z += 1;
```

Correct concept:

```dart
position.z += speed * deltaTime;
```

---

# 57. Input Queue

Fast players may perform:

```text
left
left
jump
right
slide
```

rapidly.

Create an input system rather than directly attaching every gesture to a transform.

Example:

```text
Gesture

↓

InputCommand

↓

PlayerController

↓

Validate State

↓

Execute
```

This keeps controls deterministic.

---

# 58. Collision Forgiveness

Visible models should generally be slightly larger than collision shapes.

Example:

```text
Visual obstacle

████████████

Collider

 ██████████
```

The game should favor the player on close calls.

This is particularly important at high speeds.

---

# 59. Performance Targets

Target hardware:

* mid-range Android;
* recent Android;
* older supported iPhone;
* recent iPhone.

Target:

```text
60 FPS
```

Acceptance:

```text
No increasing memory consumption over long runs.

No major frame spikes when spawning chunks.

No visible loading during gameplay.

No continuous GC stutter.

No significant input delay.
```

---

# 60. Debug Mode

Development builds should display:

```text
FPS

Frame time

Player XYZ

Speed

Current lane

Player state

Current chunk

Chunk seed

Object count

Triangle count if available

Active colliders

Difficulty

Distance
```

Optional:

```text
show collision volumes
```

This will make development dramatically easier.

---

# 61. Automated Testing

Unit test:

```text
score

economy

missions

difficulty

generation

lane rules

power-up timers

save/load
```

Generator testing is especially important.

Run:

```text
10,000+
```

generated chunk combinations.

Verify that every generated section contains a survivable route.

---

# 62. Technical Prototype — First Milestone

Before building missions, shops or characters, create:

## 3D Runner Prototype v0.1

Only:

```text
Flutter application

flutter_scene

Perspective camera

Simple 3D track

3 lanes

One GLB character

Run animation

Swipe left/right

Jump

Slide

One box obstacle

One jump obstacle

One slide obstacle

Coins

Collision

Chunk recycling

Speed increase

FPS counter
```

---

# 63. Prototype Success Criteria

Do not continue into full production until the prototype achieves:

### Visual

It clearly looks and feels three-dimensional.

### Movement

Lane switching feels immediate and smooth.

### Animation

Running/jumping/sliding blend acceptably.

### Camera

Player can clearly see upcoming hazards.

### Performance

Approximately 60 FPS on the target mid-range physical phone.

### Endless Running

Track can continue indefinitely.

### Memory

Memory does not continuously increase.

---

# 64. MVP

After validating the prototype, implement:

```text
1 environment

1 polished character

6+ obstacles

coins

4 power-ups

procedural chunks

difficulty progression

score

distance

high score

game over

restart

audio

settings

local save

tutorial
```

---

# 65. Version 1.0

Add:

```text
3–5 characters

character unlocks

missions

power-up upgrades

multiple sub-environments

better VFX

full music and SFX

progression system

revive

polished UI

advanced procedural patterns
```

---

# 66. Future Features

Potential additions:

```text
online leaderboards

daily challenges

achievements

cloud save

events

new worlds

new characters

skins

season system

special chase sequences

dynamic weather

day/night cycle
```

These should not be necessary for the initial architecture.

---

# 67. Development Priority

Build in this exact general order:

```text
1. Render one 3D GLB model

2. Perspective camera

3. 3D track

4. Character run animation

5. Lane movement

6. Jump

7. Slide

8. Collision

9. Moving world

10. Track chunk recycling

11. Procedural generator

12. Difficulty

13. Coins

14. Score

15. Power-ups

16. HUD

17. Game over

18. Persistence

19. Missions

20. Characters

21. Polish

22. Optimization
```

Do NOT begin with shop screens or progression systems.

---

# 68. Critical Technical Rule

The most important architectural decision is:

**This is an endless runner, not a general-purpose physics sandbox.**

Therefore avoid trying to simulate everything realistically.

Use deterministic systems wherever possible:

```text
Player lane
→ controlled

Player jump
→ controlled

World speed
→ controlled

Obstacle paths
→ controlled

Chunk generation
→ controlled
```

Use 3D rendering to create the visual world.

Use simple collision/physics to support gameplay.

This provides significantly more control over:

* difficulty;
* fairness;
* performance;
* bugs;
* animation timing.

---

# 69. Recommended Final Stack

```text
Application
└── Flutter

Language
└── Dart

3D Rendering
└── flutter_scene

Math / XYZ vectors
└── vector_math

3D Assets
├── GLB
└── glTF

Player Movement
└── Custom Dart kinematic controller

Collision
├── Simple 3D collision volumes
└── flutter_scene physics/query system where useful

Advanced Physics
└── flutter_scene_rapier
    only if actually required

UI
└── Flutter widgets

Persistence
└── shared_preferences or suitable Dart local storage

Audio
└── Suitable Flutter audio package

Testing
├── flutter_test
└── Dart tests
```

---

# 70. Definition of Done

The product is a successful true 3D endless runner when:

* the character is a real animated 3D model;
* the environment consists of actual 3D geometry;
* a real perspective camera is used;
* lighting affects the scene;
* the character moves across three world-space lanes;
* jumping changes actual Y position;
* obstacles occupy actual XYZ positions;
* 3D collision volumes determine hits;
* track chunks are continuously recycled;
* procedural generation can theoretically continue indefinitely;
* difficulty progressively increases;
* coins and power-ups function;
* progression persists locally;
* the player can run indefinitely until they make a mistake;
* gameplay targets a consistent 60 FPS on supported mid-range hardware;
* the complete game remains a Flutter/Dart project without Unity, Unreal or Godot.

---

# 71. Most Important Engineering Goal

Before building the full product, prove this:

```text
TRUE 3D
+
Flutter
+
60 FPS
+
animated character
+
endless procedural world
+
responsive swipe controls
```

on an actual Android/iOS device.

If that vertical slice works well, the remaining game systems can be built around it.

The **3D vertical slice is the gate for the entire project.**

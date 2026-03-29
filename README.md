# Outcast

<div align="center">
  <p><strong>A small 3D iOS exploration game built with Swift, UIKit, and SceneKit.</strong></p>
  <p>Walk from a quiet homestead into a chain of roadside maps, step inside <strong>Clear News</strong>, and explore a world that is still visibly under construction.</p>
</div>

---

## What This Project Is

Outcast is an in-progress iPhone game prototype focused on movement, atmosphere, and place.
The current build drops you into a compact 3D world where you can move on foot, drive a parked car, transition between connected roadside areas, enter buildings, and explore a growing environment anchored by a home base and the `Clear News` office.

It is intentionally small right now. The point of the project is not content volume yet, but building a playable world with clear spatial rules, solid movement, and a foundation for future interactions.

## Current Playable Slice

| Area | What is there |
| --- | --- |
| `Home` | A homestead map with trees, a house interior, a working front door, and a bed interaction sequence. |
| `Traffic 1` | The first roadside area with moving traffic and the road back home. |
| `Traffic 2` | A continuation of the traffic world with no road leading home. |
| `Traffic 3` | A much longer roadside map that leads to `Clear News`. |
| `Clear News` | A green office building with a working front door, visible interior, front desk, elevator shell, and an NPC clerk. |

## What Works Today

- Touch joystick and keyboard movement.
- Startup spawn selection for `Home` or `Clear News`.
- Scene-to-scene travel between home and three connected traffic maps.
- Animated vehicle traffic and a drivable parked car.
- Enterable interiors with roof hiding when the player moves inside.
- Basic interaction flow around the house bed and the Clear News entrance.
- Unit and UI coverage around movement, world layout, transitions, and smoke-tested launch flow.

## Tone And Direction

Outcast is aiming for something grounded and slightly strange: a rural roadside space that feels quiet, artificial, and unfinished in a deliberate way.
The project leans on simple geometry, readable silhouettes, and deterministic gameplay rules instead of heavy assets or cinematic systems.

## Tech Stack

- Swift
- UIKit
- SceneKit
- XCTest / XCUITest
- Xcode project workflow with repo-local `make` wrappers

## Run Locally

```bash
make run
```

Useful repo commands:

```bash
make build
make test
make run-device
```

If you want the raw Xcode equivalents, the project also supports:

```bash
xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build
xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test
```

## Project Shape

- `GameViewController` owns UIKit hosting, overlays, prompts, and player input wiring.
- `GameScene` owns SceneKit world construction, transitions, traffic, and per-frame simulation.
- `InputController`, `MovementSystem`, and `RoomBounds` keep movement behavior testable outside rendering code.
- `PlayerNode` is a rendering type for the character model and animation state.

## Why The README Looks Like This

This repository is documenting a living prototype, not a finished game release.
The README is meant to tell a visitor exactly what Outcast is today: a focused exploration game foundation with a specific world, a specific tone, and room to grow.

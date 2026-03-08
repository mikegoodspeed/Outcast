# Outcast Agent Guide

## Canonical Commands
- Build for the iOS Simulator: `xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build`
- Run tests with a named simulator: `xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test`
- List simulators: `xcrun simctl list devices available`
- Boot a simulator: `xcrun simctl boot 'iPhone 17 Pro'`
- Install the app on the booted simulator: `xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Outcast.app`
- Launch the app on the booted simulator: `xcrun simctl launch booted com.mike.Outcast`
- Codex Run action command: `make run`
- Codex Build action command: `make build`
- Codex Test action command: `make test`
- Repo-local wrappers:
  - `./scripts/build_sim.sh`
  - `./scripts/test_sim.sh 'iPhone 17 Pro'`
  - `./scripts/run_sim.sh 'iPhone 17 Pro'`
  - `make run`
  - `make test`

## Codex App Setup
- Set the Run action command to `make run`.
- If you want to target a different simulator from the Run action, use `SIMULATOR='iPad Pro 11-inch (M5)' make run` or another name returned by `make list-sims`.
- Use `make build` for a non-launching build and `make test` to run the full unit/UI suite.

## Architecture Boundaries
- `GameViewController` owns UIKit hosting, keyboard input, and the joystick overlay.
- `GameScene` owns SpriteKit scene orchestration only: scene setup, room rendering, and frame updates.
- `InputController` merges keyboard and touch input into a normalized movement vector and resolves source precedence.
- `MovementSystem` and `RoomBounds` remain pure Swift/CoreGraphics logic so movement rules stay testable outside SpriteKit.
- `PlayerNode` is a rendering type only. Keep gameplay rules out of it.

## Coding Standards
- Favor small, single-purpose types and methods.
- Keep gameplay math deterministic and side-effect free where practical.
- Use descriptive names over abbreviations.
- Prefer composition over inheritance unless SpriteKit/UIKit lifecycle requires subclassing.
- Add comments only where the intent is not obvious from the code.

## Testing Expectations
- Add or update unit tests for movement math, bounds clamping, and input precedence whenever those rules change.
- Keep SpriteKit-independent behavior covered in `OutcastTests`.
- Keep UI smoke coverage focused on launchability and the visible gameplay shell in `OutcastUITests`.

# Outcast Agent Guide

## Canonical Commands
- Build for the iOS Simulator: `xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build`
- Run tests with a named simulator: `xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath DerivedData test`
- Build for a connected iPhone: `xcodebuild -project Outcast.xcodeproj -scheme Outcast -destination 'generic/platform=iOS' -derivedDataPath DerivedData -allowProvisioningUpdates build`
- List simulators: `xcrun simctl list devices available`
- List connected physical devices: `xcrun devicectl list devices`
- Boot a simulator: `xcrun simctl boot 'iPhone 17 Pro'`
- Install the app on the booted simulator: `xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Outcast.app`
- Launch the app on the booted simulator: `xcrun simctl launch booted com.mike.Outcast`
- Install the app on a connected iPhone: `xcrun devicectl device install app --device <udid> DerivedData/Build/Products/Debug-iphoneos/Outcast.app`
- Launch the app on a connected iPhone: `xcrun devicectl device process launch --device <udid> --terminate-existing com.mike.Outcast`
- Codex Run action command: `make run`
- Codex Build action command: `make build`
- Codex Test action command: `make test`
- Repo-local wrappers:
  - `./scripts/build_sim.sh`
  - `./scripts/test_sim.sh 'iPhone 17 Pro'`
  - `./scripts/run_sim.sh 'iPhone 17 Pro'`
  - `./scripts/list_devices.sh`
  - `./scripts/build_device.sh`
  - `./scripts/install_device.sh`
  - `./scripts/run_device.sh`
  - `make run`
  - `make test`
  - `make build-device`
  - `make run-device`

## Codex App Setup
- Set the Run action command to `make run`.
- If you want to target a different simulator from the Run action, use `SIMULATOR='iPad Pro 11-inch (M5)' make run` or another name returned by `make list-sims`.
- Use `make build` for a non-launching build and `make test` to run the full unit/UI suite.
- `make run` remains simulator-only. Use `make run-device` for a connected iPhone.
- If more than one physical device is connected, target one explicitly with `DEVICE_ID=<udid> make run-device`.

## Physical iPhone Workflow
1. Connect the iPhone over USB, unlock it, and trust the Mac.
2. Ensure Developer Mode is enabled on the phone.
3. Confirm the phone is visible with `make list-devices`.
4. Build, install, and launch with `make run-device`.
5. If multiple phones are connected, use `DEVICE_ID=<udid> make run-device`.
6. If the device app bundle is already built and you only need to reinstall it, use `make install-device`.

## Device Signing
- The project uses automatic signing with Apple Development Team `9PKZJRD26R`.
- Physical-device deployment assumes local signing/provisioning is valid in Xcode for that team.
- Device builds use `-allowProvisioningUpdates` so Xcode can refresh or create development provisioning assets when your local Apple account is authorized to do so.
- `make build-device` and `make run-device` surface `xcodebuild` signing errors directly if provisioning is incomplete.

## Architecture Boundaries
- `GameViewController` owns UIKit hosting, keyboard input, and the joystick overlay.
- `GameScene` owns SceneKit scene orchestration only: scene setup, world rendering, and frame updates.
- `InputController` merges keyboard and touch input into a normalized movement vector and resolves source precedence.
- `MovementSystem` and `RoomBounds` remain pure Swift/CoreGraphics logic so movement rules stay testable outside SceneKit.
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

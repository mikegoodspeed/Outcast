SIMULATOR ?= iPhone 17 Pro
DERIVED_DATA_PATH ?= DerivedData
DEVICE_ID ?=

.PHONY: help build test run list-sims list-devices build-device install-device run-device

help:
	@printf "Outcast commands:\n"
	@printf "  make build          Build for iOS Simulator\n"
	@printf "  make test           Run simulator unit and UI tests\n"
	@printf "  make run            Build, install, and launch in the simulator\n"
	@printf "  make list-sims      List available iOS simulators\n"
	@printf "  make list-devices   List connected physical devices\n"
	@printf "  make build-device   Build for a connected iPhone\n"
	@printf "  make install-device Install the app on a connected iPhone\n"
	@printf "  make run-device     Build, install, and launch on a connected iPhone\n"
	@printf "\nVariables:\n"
	@printf "  SIMULATOR=%s\n" "$(SIMULATOR)"
	@printf "  DERIVED_DATA_PATH=%s\n" "$(DERIVED_DATA_PATH)"
	@printf "  DEVICE_ID=%s\n" "$${DEVICE_ID:-<auto-select first connected iPhone>}"

build:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' ./scripts/build_sim.sh

test:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' ./scripts/test_sim.sh '$(SIMULATOR)'

run:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' ./scripts/run_sim.sh '$(SIMULATOR)'

list-sims:
	xcrun simctl list devices available

list-devices:
	./scripts/list_devices.sh

build-device:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' ./scripts/build_device.sh

install-device:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' DEVICE_ID='$(DEVICE_ID)' ./scripts/install_device.sh

run-device:
	DERIVED_DATA_PATH='$(DERIVED_DATA_PATH)' DEVICE_ID='$(DEVICE_ID)' ./scripts/run_device.sh

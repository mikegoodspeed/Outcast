SIMULATOR ?= iPhone 17 Pro
DERIVED_DATA_PATH ?= DerivedData
DEVICE_ID ?=

.PHONY: build test run list-sims list-devices build-device install-device run-device

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

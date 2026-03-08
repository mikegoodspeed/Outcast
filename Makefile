SIMULATOR ?= iPhone 17 Pro

.PHONY: build test run list-sims

build:
	./scripts/build_sim.sh

test:
	./scripts/test_sim.sh '$(SIMULATOR)'

run:
	./scripts/run_sim.sh '$(SIMULATOR)'

list-sims:
	xcrun simctl list devices available


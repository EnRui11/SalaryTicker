# The front door. Every target delegates: the Packaging scripts and swift build stay the
# things that know how to build this, and a Makefile that reimplemented them would be a
# second source of truth, free to drift from the first.
#
# Two apps live here. The Mac menu bar app is the product -- `make install`. The phone and
# the watch are the same domain behind other screens, and they run on simulators.

DEVICE ?= iPhone 17
export DEVICE

.DEFAULT_GOAL := help
.PHONY: help run watch both ios app install test build xcode clean

help:
	@echo "SalaryTicker"
	@echo
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/|/' | \
		awk -F'|' '{ printf "  make %-9s %s\n", $$1, $$2 }'
	@echo
	@echo '  DEVICE="iPhone Air" make run   pick another simulator'

run: ## Phone app on the iOS simulator
	@./Packaging/build_ios.sh run

watch: ## Watch app on the paired watch simulator
	@./Packaging/build_ios.sh watch

both: ## Phone and watch together, phone first
	@./Packaging/build_ios.sh both

ios: ## Build the phone app without running it
	@./Packaging/build_ios.sh

app: ## Build SalaryTicker.app for the Mac
	@./Packaging/build_app.sh

install: ## Build the Mac app and put it in /Applications
	@./Packaging/build_app.sh install

test: ## Run the test suite
	@swift test

build: ## Compile the package
	@swift build

xcode: ## Generate the Xcode project and open it
	@xcodegen generate --spec project.yml
	@open SalaryTickerMobile.xcodeproj

clean: ## Delete every build product
	@rm -rf .build SalaryTicker.app SalaryTickerMobile.xcodeproj

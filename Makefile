PROJECT := Lexa.xcodeproj
SCHEME := Lexa
DERIVED := build
CONFIG ?= Release
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)'
APP := $(DERIVED)/Build/Products/$(CONFIG)/Lexa.app
# Stable local identity (see scripts/setup-signing.sh) so the Accessibility grant survives rebuilds.
SIGN_IDENTITY := Lexa Local Signing
HAS_IDENTITY := $(shell security find-certificate -c "$(SIGN_IDENTITY)" >/dev/null 2>&1 && echo yes)
VERSION := $(shell sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' $(PROJECT)/project.pbxproj | head -1)
DIST := $(DERIVED)/dist

ifeq ($(HAS_IDENTITY),yes)
SIGN = codesign --force --preserve-metadata=entitlements,flags --sign "$(SIGN_IDENTITY)"
else
SIGN = @echo "note: ad-hoc signed; run 'make signing' once so Accessibility access survives rebuilds:"
endif

BUILD_NUMBER := $(shell sed -n 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/p' $(PROJECT)/project.pbxproj | head -1)

.PHONY: build test run clean icon signing dist version bump release

build:
	$(XCODEBUILD) -configuration $(CONFIG) build
	$(SIGN) "$(APP)"

# Universal (Apple silicon + Intel) Release build, zipped for a GitHub release.
dist:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -destination 'generic/platform=macOS' -configuration Release ONLY_ACTIVE_ARCH=NO build
	$(SIGN) "$(DERIVED)/Build/Products/Release/Lexa.app"
	mkdir -p $(DIST)
	rm -f $(DIST)/Lexa-$(VERSION).zip
	ditto -c -k --keepParent $(DERIVED)/Build/Products/Release/Lexa.app $(DIST)/Lexa-$(VERSION).zip
	cd $(DIST) && shasum -a 256 Lexa-$(VERSION).zip | tee Lexa-$(VERSION).zip.sha256

signing:
	./scripts/setup-signing.sh

test:
	$(XCODEBUILD) -configuration Debug test

run: build
	-pkill -x Lexa
	open "$(APP)"

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf $(DERIVED)

version:
	@echo "$(VERSION) ($(BUILD_NUMBER))"

# Sets the version and increases the build number. Usage: make bump V=1.0.3
bump:
	@test -n "$(V)" || { echo "Usage: make bump V=x.y.z"; exit 1; }
	sed -i '' 's/MARKETING_VERSION = .*;/MARKETING_VERSION = $(V);/' $(PROJECT)/project.pbxproj
	sed -i '' 's/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $(shell echo $$(($(BUILD_NUMBER) + 1)));/' $(PROJECT)/project.pbxproj
	@$(MAKE) --no-print-directory version

# Publishes the GitHub release and updates the Homebrew cask. Usage: make release NOTES=notes.md
release:
	@test -n "$(NOTES)" || { echo "Usage: make release NOTES=release-notes.md"; exit 1; }
	./scripts/release.sh "$(NOTES)"

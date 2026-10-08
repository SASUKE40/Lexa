PROJECT := Lexa.xcodeproj
SCHEME := Lexa
DERIVED := build
CONFIG ?= Release
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)'
APP := $(DERIVED)/Build/Products/$(CONFIG)/Lexa.app
# Stable local identity (see scripts/setup-signing.sh) so the Accessibility grant survives rebuilds.
SIGN_IDENTITY := Lexa Local Signing
HAS_IDENTITY := $(shell security find-certificate -c "$(SIGN_IDENTITY)" >/dev/null 2>&1 && echo yes)

.PHONY: build test run clean icon signing

build:
	$(XCODEBUILD) -configuration $(CONFIG) build
ifeq ($(HAS_IDENTITY),yes)
	codesign --force --preserve-metadata=entitlements,flags --sign "$(SIGN_IDENTITY)" "$(APP)"
else
	@echo "note: ad-hoc signed; run 'make signing' once so Accessibility access survives rebuilds"
endif

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

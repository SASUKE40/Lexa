PROJECT := Lexa.xcodeproj
SCHEME := Lexa
DERIVED := build
CONFIG ?= Release
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)'
APP := $(DERIVED)/Build/Products/$(CONFIG)/Lexa.app

.PHONY: build test run clean icon

build:
	$(XCODEBUILD) -configuration $(CONFIG) build

test:
	$(XCODEBUILD) -configuration Debug test

run: build
	-pkill -x Lexa
	open "$(APP)"

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf $(DERIVED)

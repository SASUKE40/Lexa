#!/bin/sh
# Publishes the current version: GitHub release (zip + SHA-256) and the Homebrew cask.
# Usage: scripts/release.sh <release-notes.md>
# Before you start: commit all changes and set the version with `make bump V=x.y.z`.
set -eu

NOTES=${1:?"Usage: scripts/release.sh <release-notes.md>"}
VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Lexa.xcodeproj/project.pbxproj | head -1)
TAG="v$VERSION"
ZIP="build/dist/Lexa-$VERSION.zip"
TAP_REPO="SASUKE40/homebrew-tap"
TAP_DIR="build/homebrew-tap"

[ -f "$NOTES" ] || { echo "Cannot find the release notes: $NOTES"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit all changes before you release."; exit 1; }
if gh release view "$TAG" >/dev/null 2>&1; then echo "Release $TAG already exists. Use make bump."; exit 1; fi

git push origin HEAD
make dist
SHA=$(cut -d' ' -f1 "$ZIP.sha256")

gh release create "$TAG" "$ZIP" "$ZIP.sha256" \
    --target "$(git rev-parse HEAD)" --title "Lexa $VERSION" --notes-file "$NOTES"

rm -rf "$TAP_DIR"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --quiet
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP_DIR/Casks/lexa.rb"
git -C "$TAP_DIR" commit --quiet -am "lexa $VERSION"
git -C "$TAP_DIR" push --quiet
rm -rf "$TAP_DIR"

echo "Released Lexa $VERSION: https://github.com/SASUKE40/Lexa/releases/tag/$TAG"

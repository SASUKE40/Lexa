# Lexa – agent notes

Native SwiftUI menu bar app (macOS 26+, Swift 6, no third-party dependencies).

## Commands
- Build: `make build` (Release) or `make build CONFIG=Debug`
- Test: `make test` (Swift Testing, target `LexaTests`, hosted in Lexa.app)
- Run: `make run`; Debug builds accept `--demo ["text"]` to open the panel immediately
- Regenerate app icon: `make icon`

## Project layout
- `Lexa.xcodeproj` is hand-written and uses **synchronized folders**: any file added under `Lexa/` or `LexaTests/` is compiled automatically, so don't edit the pbxproj to add files. `Lexa/Info.plist` is excluded from resources via a membership exception.
- Default actor isolation is `MainActor`. Pure/background types are marked `nonisolated` (providers, parsers, diff, CLI runner); extensions of them must be `nonisolated extension` too.
- `Lexa/Providers`: `LLMBackend` protocol, `OpenAICompatibleBackend`, `CLI/` (Claude Code and Codex backends that shell out to the user's CLI), `StreamParsers.swift`.
- `Lexa/Writing`: prompts (`WritingAction`), `ResponseCleaner`, `TextDiff`.
- `Lexa/System`: Carbon hotkey, clipboard-based `TextBridge`, Accessibility, Keychain.
- App Sandbox is off on purpose (synthetic ⌘C/⌘V and launching CLIs need it off).

## Conventions
- Never read subscription tokens (`~/.codex/auth.json`, Claude keychain items). Subscription providers only drive the official CLIs.
- User text goes to CLIs via stdin, never argv.

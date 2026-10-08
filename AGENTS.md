# Lexa – agent notes

Lexa is a SwiftUI menu bar app for macOS 26 (or a newer version). It uses Swift 6 and has no third-party dependencies.

## Commands
- Build: `make build` (Release) or `make build CONFIG=Debug`.
- Test: `make test`. The tests use Swift Testing (target `LexaTests`) and operate in Lexa.app.
- Start: `make run`. Debug builds accept `--demo ["text"]`. This option opens the popup window immediately.
- App icon: `make icon` makes the icon again.
- Signing: `make signing` makes a self-signed "Lexa Local Signing" identity. If this identity is available, `make build` signs the app with it. Thus, the Accessibility (TCC) access stays after each build. An ad-hoc build loses the access after each build. To repair this problem, type `tccutil reset Accessibility com.sasuke40.lexa`.

## Project layout
- `Lexa.xcodeproj` uses **synchronized folders**. Xcode compiles all files in `Lexa/` and `LexaTests/` automatically. Do not edit the pbxproj to add files. A membership exception removes `Lexa/Info.plist` from the resources.
- The default actor isolation is `MainActor`. Pure types and background types have the `nonisolated` keyword (providers, parsers, diff, CLI runner). Their extensions must also use `nonisolated extension`.
- `Lexa/Providers`: the `LLMBackend` protocol, `OpenAICompatibleBackend`, `CLI/` (Claude Code and Codex backends that start the CLI of the user), and `StreamParsers.swift`.
- `Lexa/Writing`: prompts (`WritingAction`), `ResponseCleaner`, and `TextDiff`.
- `Lexa/System`: Carbon hotkey, `TextBridge` (clipboard), Accessibility, and Keychain.
- The App Sandbox is off. Synthetic ⌘C/⌘V and the CLI processes do not operate in the sandbox.

## Conventions
- Do not read subscription tokens (`~/.codex/auth.json`, Claude keychain items). Subscription providers only use the official CLIs.
- Send user text to a CLI through stdin. Do not put user text in argv.
- Write all user-facing text (UI, error messages, README) in ASD-STE100 Simplified Technical English:
  - Use approved words with their approved meanings. Software terms (API key, model, provider, shortcut, CLI) are technical nouns. Click, type, press, copy, paste, install, highlight, and translate are technical verbs.
  - Write a maximum of 20 words in an instruction and 25 words in a description.
  - Write one instruction in each sentence. Use the active voice.
  - Do not use contractions. Do not use the "-ing" form of a verb.
  - Do not use these words: choose (use select), need (use necessary or must), run (use start or operate), fix, check (v), test (v), retry (use try again), fail.

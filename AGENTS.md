# Lexa – agent notes

Lexa is a SwiftUI menu bar app for macOS 26 (or a newer version). It uses Swift 6 and has no third-party dependencies.

## Commands
- Build: `make build` (Release) or `make build CONFIG=Debug`.
- Test: `make test`. The tests use Swift Testing (target `LexaTests`) and operate in Lexa.app.
- Start: `make run`. Debug builds accept `--demo ["text"]`. This option opens the popup window immediately.
- App icon: `make icon` makes the icon again.
- Version: `make version` shows it. `make bump V=x.y.z` sets `MARKETING_VERSION` and increases `CURRENT_PROJECT_VERSION`.
- Publish: `make release NOTES=notes.md` (`scripts/release.sh`) pushes, runs `make dist`, makes the GitHub release, and updates `Casks/lexa.rb` in `SASUKE40/homebrew-tap`. The tree must be clean, and the tag must not exist.
- Updates (`Lexa/Updates`): `Updater` reads `releases/latest` from the GitHub API on launch and each day. `UpdateInstaller` downloads `Lexa-<version>.zip`, compares it with `Lexa-<version>.zip.sha256`, and accepts the app only if it satisfies the designated requirement of the running app (same bundle ID and signing certificate). Then a `/bin/sh` script replaces the app after Lexa quits and opens it again. Homebrew installs (a `Caskroom/lexa` folder exists) show `brew upgrade --cask lexa` instead.
- Release: `make dist` builds a universal (arm64 and x86_64) Release version and makes `build/dist/Lexa-<version>.zip` and a SHA-256 file. The version comes from `MARKETING_VERSION` in the pbxproj. Publish with `gh release create v<version> build/dist/Lexa-<version>.zip`.
- Code coverage: the shared scheme has `codeCoverageEnabled = "NO"` and no automatic test plan. If coverage is on, Release builds include profile code and write `default.profraw` files.
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
- Sign-in (`Lexa/Providers/OAuth`): OpenRouter uses the official PKCE procedure with a loopback callback (`LoopbackServer`) and stores the new API key. Nous Portal and GitHub use the device authorization grant (`DeviceFlow`, RFC 8628). `NousSession` keeps the Nous tokens in the Keychain and refreshes them. Nous refresh tokens are single-use, so only one refresh runs at a time. The GitHub CLI token comes from `gh auth token`, which is the official way to give it to other tools.
- The Nous sign-in uses the public `hermes-cli` client ID because Nous has no public client registration. Keep the disclosure in Settings and in the README.
- `GitHubOAuth.clientID` is the client ID of the Lexa GitHub OAuth App (device flow on). If it is empty, Settings does not show "Sign in with GitHub".
- Send user text to a CLI through stdin. Do not put user text in argv.
- Keep README.md short (installation, procedure, providers, updates, privacy). Put developer details in docs/DEVELOPMENT.md.
- Write all user-facing text (UI, error messages, README, docs) in ASD-STE100 Simplified Technical English:
  - Use approved words with their approved meanings. Software terms (API key, model, provider, shortcut, CLI) are technical nouns. Click, type, press, copy, paste, install, highlight, and translate are technical verbs.
  - Write a maximum of 20 words in an instruction and 25 words in a description.
  - Write one instruction in each sentence. Use the active voice.
  - Do not use contractions. Do not use the "-ing" form of a verb.
  - Do not use these words: choose (use select), need (use necessary or must), run (use start or operate), fix, check (v), test (v), retry (use try again), fail.

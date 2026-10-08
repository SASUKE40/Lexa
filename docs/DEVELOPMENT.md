# Lexa development

You must have macOS 26 (or a newer version) and Xcode 26 (or a newer version). Lexa has no third-party dependencies.

## Commands

| Command | Result |
|---|---|
| `make signing` | Makes a self-signed "Lexa Local Signing" certificate. Do this one time. |
| `make run` | Builds the Release version and starts it. |
| `make build` | Builds only. Use `CONFIG=Debug` for a Debug build. |
| `make test` | Does the unit tests. |
| `make dist` | Builds a universal Release version and makes `build/dist/Lexa-x.y.z.zip`. |
| `make version` | Shows the version and the build number. |
| `make bump V=x.y.z` | Sets the version and increases the build number. |
| `make release NOTES=notes.md` | Publishes the GitHub release and updates the Homebrew cask. |

You can also open `Lexa.xcodeproj` in Xcode and press ⌘R. Debug builds accept `--demo ["some text"]`. This option opens the popup window with sample text.

## Signing and Accessibility

macOS keeps the Accessibility access for one app signature only. An ad-hoc build ("Sign to Run Locally") gets a new signature after each build. Then the access stops, but System Settings continues to show Lexa as enabled.

`make signing` makes a certificate in your login keychain. Then `make build` signs the app with this certificate, and the access stays after each build. If Lexa continues to tell you to give access, remove its entry. Then give access again:

```sh
tccutil reset Accessibility com.sasuke40.lexa
```

## Release procedure

Lexa uses semantic versions (`MAJOR.MINOR.PATCH`) and Git tags (`vX.Y.Z`).

1. Set the new version: `make bump V=1.0.5`.
2. Commit the changes.
3. Write the release notes in a Markdown file.
4. Publish: `make release NOTES=notes.md`.

The release command builds the zip, makes the GitHub release, and updates the cask in [SASUKE40/homebrew-tap](https://github.com/SASUKE40/homebrew-tap).

The in-app update downloads `Lexa-x.y.z.zip` and compares it with `Lexa-x.y.z.zip.sha256`. Then it makes sure that the new app has the same code signature as the installed app. Sign all releases with the same certificate. If the signature changes, the in-app update does not install the release.

## Sign-in

- **OpenRouter**: Lexa uses the official OAuth PKCE procedure with a callback to `localhost`. OpenRouter makes a new API key for Lexa.
- **Nous Portal**: Lexa uses the device authorization grant (RFC 8628). Lexa refreshes the token automatically.
- **GitHub**: Lexa uses the device authorization grant with the Lexa OAuth App, or the token from `gh auth token`.

## Subscription providers

Lexa starts the signed-in `codex exec` or `claude -p` CLI on your Mac. Lexa sends the text through stdin. The CLI operates in an empty temporary folder, and its tools are disabled.

- **ChatGPT**: Lexa uses the first model in the Codex model list (`~/.codex/models_cache.json`).
- **Claude**: Lexa uses the `opus` alias, which always points to the newest Claude Opus model.

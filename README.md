<p align="center">
  <img src="Lexa/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Lexa icon">
</p>

<h1 align="center">Lexa</h1>

<p align="center">
  A small Grammarly alternative for macOS.<br>
  Use a free LLM key, a local model, or your ChatGPT or Claude subscription.
</p>

<p align="center">
  <a href="https://github.com/SASUKE40/Lexa/releases/latest"><img src="https://img.shields.io/badge/Download-Lexa%20for%20macOS-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="Download Lexa for macOS"></a>
</p>

<p align="center">
  <a href="https://github.com/SASUKE40/Lexa/releases/latest"><img src="https://img.shields.io/github/v/release/SASUKE40/Lexa?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen" alt="No dependencies">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"></a>
</p>

Select text in an app. Then press **⌥⌘G**. Lexa shows a corrected version of the text and highlights the changes. Press **↩** to replace the selected text.

## Video

https://github.com/user-attachments/assets/a1467c7b-f5d9-444c-9aac-b6fd7a29da73

The model results in the video are examples from a local test server. You can also download the [full-quality video](docs/lexa.mp4).

## Installation

You must have macOS 26 (or a newer version).

### Homebrew

```sh
brew install --cask sasuke40/tap/lexa
```

### Download

1. Download `Lexa-x.y.z.zip` from the [latest release](https://github.com/SASUKE40/Lexa/releases/latest).
2. Open the zip file.
3. Move `Lexa.app` to the Applications folder.
4. Open Lexa.
5. If macOS does not open Lexa, go to **System Settings → Privacy & Security**. Then click **Open Anyway**.
6. Give Accessibility access when Lexa tells you to.

Apple did not notarize Lexa. Thus, macOS shows a warning when you open Lexa for the first time.

### Updates

Lexa looks for a new release on GitHub when it starts and one time each day. You can see the version and the update status in **Settings → General → Updates**, or click **Find Updates…** in the menu bar menu.

- If you downloaded Lexa, click **Install the Update**. Lexa downloads the new version and makes sure that its SHA-256 and its code signature are correct. Then Lexa replaces the app and starts again. Your settings and your Accessibility access stay the same.
- If you installed Lexa with Homebrew, type `brew upgrade --cask lexa`.

To stop the automatic search, turn off **Find updates automatically**.

## Functions

- **Correct**: Lexa corrects the grammar, spelling, and punctuation. It makes only the necessary changes.
- **Make Clear**: Lexa writes the text again in [ASD-STE100 Simplified Technical English](https://www.asd-ste100.org). The result has short sentences, the active voice, and only approved words. A large model (for example, Claude Sonnet) obeys the STE rules better than a small model.
- **Tone**: Lexa changes the text to a Formal, Friendly, Short, or Confident tone.
- **Translate**: Lexa translates the text into one of 15 languages.
- Lexa shows each changed word in color.
- Lexa shows the result while the model sends it.
- The popup window uses macOS Liquid Glass.
- Lexa is a menu bar app. It does not show an icon in the Dock.
- You can change the shortcut. Lexa can start at login.
- After each copy and paste, Lexa puts the previous clipboard contents back.

## Procedure

1. Select text in an app. For example, use Mail, Notes, Slack, or a web browser.
2. Press **⌥⌘G**. Lexa starts the default action (Correct) immediately.
3. Look at the highlighted changes.
4. Use one of these keys:

| Key | Action |
|---|---|
| ↩ | Replace the selected text |
| ⌘C | Copy the result |
| ⌘R | Try again |
| ⌘1 / ⌘2 | Correct / Make Clear |
| Esc | Close the popup window |

To change the shortcut, the default action, or the language for Translate, open **Settings**. Click the menu bar icon, then click **Settings…**.

## Providers

| Provider | Type | Access |
|---|---|---|
| OpenRouter | Free models (`openrouter/free` or a `:free` model) | **Sign in with OpenRouter**, or an API key from https://openrouter.ai/keys |
| Nous Portal | Your Nous Portal subscription, or Hermes models | **Sign in with Nous Portal**, or an API key from https://portal.nousresearch.com |
| Groq | Free to use, with a rate limit | https://console.groq.com/keys |
| Cerebras | Free to use, with a rate limit | https://cloud.cerebras.ai |
| Google Gemini | Free to use, with a rate limit | https://aistudio.google.com/apikey |
| Mistral | Free "Experiment" plan | https://console.mistral.ai/api-keys |
| GitHub Models | Free with a GitHub account | **Sign in with GitHub**, the GitHub CLI login (`gh`), or a token (`models: read`) |
| Ollama / LM Studio | Local. An internet connection and a key are not necessary. | https://ollama.com · https://lmstudio.ai |
| Custom | A server with an OpenAI-compatible `/chat/completions` endpoint | |
| **ChatGPT (Codex CLI)** | Your ChatGPT plan | Install `codex`. Then type `codex login`. |
| **Claude (Claude Code CLI)** | Your Claude Pro or Max plan | Install `claude`. Then type `claude auth login`. |

Lexa keeps API keys and sign-in tokens in the macOS Keychain. You can change the model name. **Download the Model List** shows the models that your key can use. The list of free models changes frequently.

### Sign-in

- **OpenRouter**: Lexa uses the official OpenRouter OAuth PKCE procedure. Your browser opens, and you give access. Then OpenRouter makes a new API key for Lexa. You can delete this key at https://openrouter.ai/keys.
- **Nous Portal**: Lexa shows a code and opens the Nous Portal page. Make sure that the page shows the code. Then give access. Lexa refreshes the token automatically.
- **GitHub**: Lexa shows a code and opens the GitHub page. Paste the code, and give access. Or use the token of the GitHub CLI (`gh auth token`).

Nous Research does not have a public sign-in for other apps. Thus, the Nous Portal sign-in uses the public client ID of Hermes Agent. Nous Research did not give Lexa permission for this sign-in, and it can stop at any time. If it stops, use an API key.

### Subscription providers

For a subscription, Lexa starts your signed-in CLI on your Mac (`codex exec` or `claude -p`). Lexa does not read, keep, or send the credentials of the CLI.

Lexa sends the text to the CLI through stdin. The CLI operates in an empty temporary folder, and its tools are disabled:

- For Claude, Lexa uses `--tools ""`.
- For Codex, Lexa uses a read-only sandbox.

Lexa uses the newest model of each subscription:

- For ChatGPT, Lexa reads the model list of the Codex CLI (`~/.codex/models_cache.json`) and uses the first model in it. This file has no credentials.
- For Claude, Lexa uses the `opus` alias. This alias always points to the newest Claude Opus model.

You can select a different model in Settings. Lexa uses low reasoning effort to make the result faster.

These providers are slower than API providers. Each result can take some seconds more.

Use this alternative only for your work, and obey the terms of your plan. Anthropic does not let other products use Claude Free, Pro, or Max credentials for their users.

## Build and start

You must have macOS 26 (or a newer version) and Xcode 26 (or a newer version).

```sh
make signing # Do one time: make a local signing certificate (Lexa keeps Accessibility access after each build)
make run     # Build the Release version and start it
make test    # Do the unit tests
make build   # Build only (CONFIG=Debug for a Debug build)
make dist    # Build a universal Release version and make build/dist/Lexa-x.y.z.zip
```

### Release procedure

Lexa uses semantic versions (`MAJOR.MINOR.PATCH`) and Git tags (`vX.Y.Z`).

1. Set the new version: `make bump V=1.0.3`. This command also increases the build number.
2. Commit the changes.
3. Write the release notes in a Markdown file.
4. Publish: `make release NOTES=notes.md`. This command builds the zip, makes the GitHub release, and updates the Homebrew cask in [SASUKE40/homebrew-tap](https://github.com/SASUKE40/homebrew-tap).

The in-app update uses the `Lexa-x.y.z.zip` and `Lexa-x.y.z.zip.sha256` files of the release. Sign all releases with the same certificate. If the signature changes, the in-app update does not install the release.

You can also open `Lexa.xcodeproj` in Xcode and press ⌘R.

For development, Debug builds accept `--demo ["some text"]`. This option opens the popup window with sample text.

## Permissions

Lexa must have **Accessibility** access to copy the selected text and paste the result. To give access, go to **System Settings → Privacy & Security → Accessibility**. The global shortcut does not use a permission.

macOS keeps the Accessibility access for one app signature only. An ad-hoc signed build ("Sign to Run Locally", for example ⌘R in Xcode) gets a new signature after each build. Then the access stops, but System Settings continues to show Lexa as enabled.

`make signing` makes a self-signed "Lexa Local Signing" certificate in your login keychain. Then `make build` and `make run` sign the app with this certificate. Thus, you give access only one time.

If Lexa continues to tell you to give access, remove its entry. Then give access again:

```sh
tccutil reset Accessibility com.sasuke40.lexa
```

## Privacy

Lexa sends your text only to the provider that you select. With Ollama or LM Studio, your text stays on your Mac.

## License

[MIT](LICENSE)

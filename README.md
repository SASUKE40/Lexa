<p align="center">
  <img src="Lexa/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Lexa icon">
</p>

<h1 align="center">Lexa</h1>

<p align="center">
  A tiny, native Grammarly alternative for macOS.<br>
  Bring a free LLM key, a local model, or the ChatGPT / Claude subscription you already have.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen" alt="No dependencies">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"></a>
</p>

Select text in any app, press **⌥⌘G**, and Lexa shows a corrected version with the changes highlighted. Press **↩** to replace your selection.

## Features

- **Fix**: grammar, spelling and punctuation, with minimal edits
- **Improve**: clearer, smoother wording
- **Tone**: Formal, Friendly, Concise or Confident
- **Translate**: into 15 languages
- Word-level diff, streaming output, and a Liquid Glass popup
- Menu bar only (no Dock icon), with a configurable shortcut and launch at login
- Restores your clipboard after copying and pasting

## Usage

1. Select text in any app (Mail, Notes, Slack, your browser…).
2. Press **⌥⌘G**. The default action (Fix) runs right away.
3. Review the highlighted changes, then:

| Key | Action |
|---|---|
| ↩ | Replace the selection |
| ⌘C | Copy the result |
| ⌘R | Retry |
| ⌘1 / ⌘2 | Fix / Improve |
| Esc | Close |

The shortcut, default action and translation language can be changed in **Settings** (menu bar icon → Settings…).

## Providers

| Provider | Type | Get access |
|---|---|---|
| OpenRouter | Free models (`openrouter/free` or any `:free` model) | https://openrouter.ai/keys |
| Nous Portal | Hermes models | https://portal.nousresearch.com |
| Groq | Free tier | https://console.groq.com/keys |
| Cerebras | Free tier | https://cloud.cerebras.ai |
| Google Gemini | Free tier | https://aistudio.google.com/apikey |
| Mistral | Free "Experiment" plan | https://console.mistral.ai/api-keys |
| GitHub Models | Free with a GitHub token (`models: read`) | https://github.com/settings/personal-access-tokens |
| Ollama / LM Studio | Local, offline, no key | https://ollama.com · https://lmstudio.ai |
| Custom | Any OpenAI-compatible `/chat/completions` endpoint | |
| **ChatGPT (Codex CLI)** | Your ChatGPT plan | Install `codex`, then run `codex login` |
| **Claude (Claude Code CLI)** | Your Claude Pro/Max plan | Install `claude`, then run `claude auth login` |

API keys are stored in the macOS Keychain. Model names are editable, and **Fetch Models** lists what your key can use. Free model lineups change often.

### About the subscription providers

For subscriptions, Lexa runs your **own signed-in CLI** on your Mac (`codex exec` / `claude -p`) and never reads, stores or sends its credentials.

The text goes to the CLI through stdin. The CLI runs in an empty temporary folder with tools disabled: Claude with `--tools ""`, Codex in a read-only sandbox. These providers take a few seconds longer than API providers.

This is for personal use under your plan's terms. Anthropic doesn't allow third-party products to route requests through Claude Free/Pro/Max credentials on behalf of their users.

## Build & run

Requires macOS 26+ and Xcode 26+.

```sh
make signing # once: create a local signing certificate (keeps Accessibility access across rebuilds)
make run     # build Release and launch
make test    # run unit tests
make build   # build only (CONFIG=Debug for a debug build)
```

Or open `Lexa.xcodeproj` in Xcode and press ⌘R. For development, `Lexa --demo ["some text"]` (Debug builds) opens the panel with sample text.

## Permissions

Lexa needs **Accessibility** access (System Settings → Privacy & Security → Accessibility) to copy the selected text and paste the result back. The global shortcut itself needs no permission.

macOS ties the Accessibility grant to the app's signature. Ad-hoc signed builds ("Sign to Run Locally", e.g. ⌘R in Xcode) get a new signature on every rebuild, so the grant stops working even though Lexa still looks enabled in System Settings.

`make signing` creates a self-signed "Lexa Local Signing" certificate in your login keychain, and `make build` / `make run` then sign with it, so you only grant access once. If Lexa keeps asking, reset its entry and grant again:

```sh
tccutil reset Accessibility com.sasuke40.lexa
```

## Privacy

Your text goes only to the provider you choose. Ollama and LM Studio keep everything on your Mac.

## License

[MIT](LICENSE)

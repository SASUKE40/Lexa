# Lexa

A small, native macOS writing assistant. Select text in any app, press **⌥⌘G**, and Lexa shows a corrected version with the changes highlighted. Press **↩** to replace your selection.

Lexa works with free LLM providers, with local models, and with the ChatGPT or Claude subscription you already pay for.

## Features

- **Fix**: grammar, spelling and punctuation, with minimal edits
- **Improve**: clearer, smoother wording
- **Tone**: Formal, Friendly, Concise or Confident
- **Translate**: into 15 languages
- Word-level diff, streaming output, and a Liquid Glass popup
- Menu bar only (no Dock icon), with a configurable shortcut and launch at login
- Restores your clipboard after copying and pasting

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
make run     # build Release and launch
make test    # run unit tests
make build   # build only (CONFIG=Debug for a debug build)
```

Or open `Lexa.xcodeproj` in Xcode and press ⌘R. For development, `Lexa --demo ["some text"]` (Debug builds) opens the panel with sample text.

## Permissions

Lexa needs **Accessibility** access (System Settings → Privacy & Security → Accessibility) to copy the selected text and paste the result back. The global shortcut itself needs no permission.

The app is signed ad-hoc ("Sign to Run Locally"). After each rebuild, macOS may treat it as a new app:

- You may need to toggle Lexa off and on again in the Accessibility list.
- You may need to click *Always Allow* when Lexa reads its Keychain item.

Setting a development team in Xcode avoids both.

## Privacy

Your text goes only to the provider you choose. Ollama and LM Studio keep everything on your Mac.

# Claude Copilot Button

VS Code extension that adds a teal button next to the Claude Code button in the editor title bar. Clicking it opens a terminal running Claude Code routed to **GitHub Copilot models** (default `gpt-5.6-sol`) through your personal Copilot Pro+ subscription.

Sibling to the `claude-abliterated` and `claude-glm` button extensions, same pattern.

## Use

- Click the teal button in the editor title bar, or press `Ctrl+Shift+Alt+C`.
- A terminal opens and runs `claude-copilot.ps1`, which boots a local `@jeffreycao/copilot-api` proxy, points Claude Code at it, and launches `claude --model gpt-5.6-sol`. The proxy is stopped and env restored when you close the session.

## How it works

- Claude Code chooses its backend via `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN=dummy`; it needs an Anthropic `/v1/messages` server.
- The `@jeffreycao/copilot-api` fork is that server: it serves `/v1/messages` and routes per-model to Copilot's `/responses` (required by gpt-5.x / grok / codex) vs `/chat/completions`.
- `CLAUDE_CODE_MAX_CONTEXT_TOKENS=400000` gives `sol` its real window (else the harness assumes 200k).

## One-time setup

1. Node + `claude` on PATH.
2. Copilot auth: `npx copilot-api@latest auth` (token lands at `~/.local/share/copilot-api/github_token`, reused via `-g`).
3. `~/.claude/settings.json` -> `availableModels` must list `gpt-5.6-sol`, or Claude silently overrides it with "restricted by your organization's settings". Already added.

## Caveats

Usage-based billing; `sol` is premium. Using Copilot outside sanctioned clients is against its ToS (account-flag risk).

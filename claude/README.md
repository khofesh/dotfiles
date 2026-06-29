# claude

Helpers for Claude Code.

Two ways to keep personal and work accounts apart:

- **`scripts/claude-slash.sh`** (recommended) — two fully separate config directories.
  Complete isolation, no swapping, both can run at once.
- **`scripts/claude-profile.sh`** — one config dir, swaps only the login identity in/out.
  Older approach; superseded by `claude-slash` but kept for reference.

## scripts/claude-slash.sh

Run Claude Code against a second, fully independent config directory for the work account.

Claude Code reads **everything** — credentials, `settings.json`, MCP servers, project
history, memory, agents — from `$CLAUDE_CONFIG_DIR` (default `~/.claude`). Pointing it at a
second directory gives a completely isolated account:

```
~/.claude          → personal (the default, no env var needed)
~/.claude-slash    → work     (CLAUDE_CONFIG_DIR=~/.claude-slash)
```

The two configs are independent: settings, MCP servers, agents, and history are **not**
shared. Configure each directory on its own.

### Install

Symlink it into `~/.local/bin/` (assumed to be on your `PATH`) so it's callable as `claude-slash`:

```bash
ln -sf "$PWD/scripts/claude-slash.sh" ~/.local/bin/claude-slash
```

### First-time setup

```bash
claude-slash      # starts Claude Code against ~/.claude-slash
/login            # log into the work account
```

### Usage

```bash
claude            # personal account (~/.claude)
claude-slash      # work account     (~/.claude-slash)
```

No quit/restart to switch — just pick the command. You can run both at the same time in
separate terminals.

### Notes

- Override the work dir with `CLAUDE_SLASH_DIR=/some/path claude-slash` if you don't want
  `~/.claude-slash`.
- `~/.claude-slash` holds live OAuth tokens — keep it out of any committed/synced dotfiles.

## scripts/claude-profile.sh

Switch the Claude Code login between accounts (e.g. personal / company) within a **single**
config dir. Superseded by `claude-slash` above; use that instead unless you specifically want
both accounts to share settings/MCP/history.

### Install

Symlink it into `~/.local/bin/` (assumed to be on your `PATH`) so it's callable as `claude-profile`:

```bash
ln -sf "$PWD/scripts/claude-profile.sh" ~/.local/bin/claude-profile
```

### How it works

Claude Code's login identity lives in two files, so the script swaps both:

- `~/.claude/.credentials.json` — the OAuth tokens
- `~/.claude.json` — only the `oauthAccount` / `userID` / `organizationUuid` keys are
  touched; the rest of that file (project history, settings) is left intact via a Python merge.

### First-time setup

Snapshot each account once. Start from whichever account you're already logged into:

```bash
# 1. you're logged into your personal account → save it
claude-profile save personal

# 2. log out and into the company account in Claude Code (/login), then save it
claude-profile save company
```

Order doesn't matter — just save each profile while logged into that account.

### Usage

```bash
# day to day (quit Claude Code first, restart after):
claude-profile switch company
claude-profile switch personal

claude-profile list      # * marks the active one
claude-profile current   # show who you're logged in as now
```

### Notes

- Each `switch` first backs up the current login to `~/.claude/profiles/.backup-<timestamp>/`,
  so a bad swap is recoverable.
- Profiles are stored under `~/.claude/profiles/`. These contain live OAuth tokens — keep them
  out of any committed/synced dotfiles (the script keeps them in `~/.claude`, not in the repo).
- Quit Claude Code before switching and restart afterward, since it reads these files at startup.

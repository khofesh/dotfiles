# claude

Helpers for Claude Code.

## scripts/claude-profile.sh

Switch the Claude Code login between accounts (e.g. personal / company).

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

#!/usr/bin/env bash
#
# claude-slash — run Claude Code against a separate config directory (the work account).
#
# Claude Code reads everything — credentials, settings, MCP servers, history, memory,
# agents — from $CLAUDE_CONFIG_DIR (default ~/.claude). Pointing it at a second directory
# gives a fully isolated account: personal stays in ~/.claude, work lives in ~/.claude-slash.
#
# No swapping, no quit/restart, and both can run at once in different terminals.
#
# Usage:
#   claude-slash [args...]    Run Claude Code with CLAUDE_CONFIG_DIR=~/.claude-slash
#
# First-time setup: run `claude-slash`, then `/login` into the work account.

set -euo pipefail

export CLAUDE_CONFIG_DIR="${CLAUDE_SLASH_DIR:-$HOME/.claude-slash}"

exec claude "$@"

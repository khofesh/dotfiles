#!/usr/bin/env bash
pkill -f --signal SIGTERM gnome-keyring-daemon

# Start and export environment variables
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg)
export SSH_AUTH_SOCK

# GitHub SSH Key Setup on Linux

How to generate an SSH key, connect it to GitHub, and use it for git operations. Includes custom key filenames and multiple accounts.

## Table of Contents

1. [Check for existing keys](#1-check-for-existing-keys)
2. [Generate a new key](#2-generate-a-new-key)
3. [Configure SSH to use the key](#3-configure-ssh-to-use-the-key)
4. [Add the key to the SSH agent](#4-add-the-key-to-the-ssh-agent)
5. [Add the public key to GitHub](#5-add-the-public-key-to-github)
6. [Test the connection](#6-test-the-connection)
7. [Use SSH remotes](#7-use-ssh-remotes)
8. [Renaming an existing key](#renaming-an-existing-key)
9. [Multiple GitHub accounts](#multiple-github-accounts)
10. [Troubleshooting](#troubleshooting)

## 1. Check for existing keys

```bash
ls -al ~/.ssh
```

Look for files like `id_ed25519` / `id_ed25519.pub` or `id_rsa` / `id_rsa.pub`. If you already have a key you want to use, skip to step 3.

## 2. Generate a new key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/github_personal
```

- `-t ed25519` selects the key type (modern, short, fast).
- `-C` adds a comment label, usually your email.
- `-f` sets a custom filename. Without it, the default is `~/.ssh/id_ed25519`. The name is arbitrary.
- Set a passphrase when prompted (recommended).

This creates:

| File | Purpose |
| --- | --- |
| `~/.ssh/github_personal` | Private key. Never share it. |
| `~/.ssh/github_personal.pub` | Public key. This is what you give GitHub. |

If your system is very old and does not support Ed25519:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/github_personal
```

## 3. Configure SSH to use the key

With a non-default filename, SSH will not find the key automatically. Add this to `~/.ssh/config` (create the file if it does not exist):

```
Host github.com
    AddKeysToAgent yes
    IdentityFile ~/.ssh/github_personal
    IdentitiesOnly yes
```

- `AddKeysToAgent yes` loads the key into the agent on first use, so you are not asked for the passphrase every time.
- `IdentitiesOnly yes` makes SSH offer only this key instead of trying every key in the agent, which avoids "too many authentication failures".

Set safe permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/github_personal
```

## 4. Add the key to the SSH agent

Start the agent and add the key:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github_personal
```

If you set `AddKeysToAgent yes` in the config, this step happens automatically on first connection, but you still need a running agent.

## 5. Add the public key to GitHub

Print the public key and copy the whole output:

```bash
cat ~/.ssh/github_personal.pub
```

Or copy it directly:

```bash
# X11
xclip -selection clipboard < ~/.ssh/github_personal.pub

# Wayland
wl-copy < ~/.ssh/github_personal.pub
```

Then on GitHub:

1. Go to **Settings → SSH and GPG keys → New SSH key**.
2. Enter a title (for example, the name of your machine).
3. Keep the key type as **Authentication Key**.
4. Paste the public key and click **Add SSH key**.

GitHub's menu labels can change. If something looks different, see GitHub's documentation: "Connecting to GitHub with SSH".

## 6. Test the connection

```bash
ssh -T git@github.com
```

On first connection, SSH asks you to confirm the host fingerprint. Compare it with the fingerprints published in GitHub's documentation before typing `yes`.

Expected result:

```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## 7. Use SSH remotes

Clone a new repository over SSH:

```bash
git clone git@github.com:user/repo.git
```

Switch an existing repository from HTTPS to SSH:

```bash
git remote set-url origin git@github.com:user/repo.git
git remote -v   # verify
```

## Renaming an existing key

Renaming is safe. GitHub only cares about the public key contents, so you do not need to re-upload anything.

```bash
mv ~/.ssh/id_ed25519 ~/.ssh/github_personal
mv ~/.ssh/id_ed25519.pub ~/.ssh/github_personal.pub
```

Then update `IdentityFile` in `~/.ssh/config` and re-add the key to the agent:

```bash
ssh-add ~/.ssh/github_personal
```

## Multiple GitHub accounts

Use separate keys and host aliases in `~/.ssh/config`:

```
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_personal
    IdentitiesOnly yes

Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_work
    IdentitiesOnly yes
```

Use the alias in place of `github.com` when cloning or setting remotes:

```bash
git clone git@github-personal:user/repo.git
git remote set-url origin git@github-work:org/repo.git
```

Test each alias:

```bash
ssh -T git@github-personal
ssh -T git@github-work
```

Note: a given public key can only be attached to one GitHub account, so each account needs its own key.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Permission denied (publickey)` | Run `ssh -vT git@github.com` to see which key is offered. Confirm the matching public key is added to your GitHub account and that `IdentityFile` points to the right path. |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | `chmod 700 ~/.ssh && chmod 600 ~/.ssh/github_personal` |
| Passphrase prompt on every operation | Use `AddKeysToAgent yes` in the config, or a keychain tool such as `keychain`. |
| `Too many authentication failures` | Add `IdentitiesOnly yes` to the host entry. |
| Port 22 blocked (corporate network) | Use SSH over port 443 (see below). |
| `Could not open a connection to your authentication agent` | Start the agent: `eval "$(ssh-agent -s)"` |

### SSH over port 443

If port 22 is blocked, add this to `~/.ssh/config`:

```
Host github.com
    Hostname ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/github_personal
    IdentitiesOnly yes
```

Test with:

```bash
ssh -T -p 443 git@ssh.github.com
```

## Security notes

- Never share or commit your private key (`github_personal`). Only the `.pub` file is safe to share.
- Use a passphrase on your key.
- If a key is ever exposed, delete it from GitHub (Settings → SSH and GPG keys) and generate a new one.

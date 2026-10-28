# Docker on macOS without Docker Desktop

How to run Docker on a MacBook (Apple Silicon) using [Colima](https://github.com/abiosoft/colima) instead of Docker Desktop. Colima runs a small Linux VM (via [Lima](https://github.com/lima-vm/lima)) with the Docker engine inside, and the regular `docker` CLI on macOS talks to it.

## Table of Contents

1. [Install](#1-install)
2. [Start Colima](#2-start-colima)
3. [Verify](#3-verify)
4. [Configure the credential helper](#4-configure-the-credential-helper)
5. [Docker Compose and Buildx](#5-docker-compose-and-buildx)
6. [Start on login](#6-start-on-login)
7. [Day-to-day commands](#7-day-to-day-commands)
8. [Resources (CPU, memory, disk)](#resources-cpu-memory-disk)
9. [Running x86_64 (amd64) images](#running-x86_64-amd64-images)
10. [Volumes and file sharing](#volumes-and-file-sharing)
11. [Tools that expect /var/run/docker.sock](#tools-that-expect-varrundockersock)
12. [Removing Docker Desktop leftovers](#removing-docker-desktop-leftovers)
13. [Troubleshooting](#troubleshooting)

## 1. Install

```bash
brew install docker docker-credential-helper colima
```

| Package | Purpose |
| --- | --- |
| `docker` | The Docker CLI only (no engine, no GUI). |
| `docker-credential-helper` | Provides `docker-credential-osxkeychain`, so registry logins are stored in the macOS Keychain instead of plain text. |
| `colima` | Manages the Linux VM that runs the Docker engine. Pulls in `lima` as a dependency. |

## 2. Start Colima

```bash
colima start
```

The first run downloads a disk image and provisions Docker (about 30 seconds):

```
INFO[0000] starting colima
INFO[0000] runtime: docker
INFO[0000] creating and starting ...                     context=vm
INFO[0001] downloading disk image ...                    context=vm
INFO[0030] provisioning ...                              context=docker
INFO[0031] starting ...                                  context=docker
INFO[0032] done
```

Colima also creates a Docker context named `colima` and switches to it, so the `docker` CLI talks to the VM automatically.

Defaults are 2 CPUs, 2 GiB memory and 100 GiB disk. See [Resources](#resources-cpu-memory-disk) to change them.

## 3. Verify

```bash
docker ps
```

```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

An empty table means the CLI reached the engine. Run a real container to be sure:

```bash
docker run --rm hello-world
docker context ls        # "colima" should be marked with *
colima status
```

## 4. Configure the credential helper

Tell Docker to store registry credentials in the Keychain. Edit (or create) `~/.docker/config.json`:

```json
{
  "credsStore": "osxkeychain"
}
```

Then log in as usual:

```bash
docker login                  # Docker Hub
docker login ghcr.io          # GitHub Container Registry
```

If `~/.docker/config.json` already exists, merge the key into it rather than overwriting the file.

## 5. Docker Compose and Buildx

The Homebrew `docker` formula does not include the `compose` or `buildx` plugins. Install them:

```bash
brew install docker-compose docker-buildx
```

Then let the Docker CLI find Homebrew's plugin directory by adding `cliPluginsExtraDirs` to `~/.docker/config.json`:

```json
{
  "credsStore": "osxkeychain",
  "cliPluginsExtraDirs": [
    "/opt/homebrew/lib/docker/cli-plugins"
  ]
}
```

Verify:

```bash
docker compose version
docker buildx version
```

## 6. Start on login

Either start Colima manually when you need it (`colima start`), or run it as a background service that starts at login:

```bash
brew services start colima
```

Stop the service with `brew services stop colima`. Do not mix the two: if the service is running, use `brew services` to stop and start it.

## 7. Day-to-day commands

| Command | What it does |
| --- | --- |
| `colima start` | Start the VM (creates it on first run). |
| `colima stop` | Stop the VM. Containers and images are kept. |
| `colima restart` | Restart the VM. |
| `colima status` | Show whether the VM is running, its arch, runtime and socket. |
| `colima list` | List all Colima profiles (instances). |
| `colima ssh` | Open a shell inside the VM. |
| `colima delete` | Delete the VM **and all images, containers and volumes** in it. |

Published ports (`docker run -p 8080:80 ...`) are forwarded to `localhost` on the Mac automatically.

## Resources (CPU, memory, disk)

Pass flags on start:

```bash
colima start --cpu 4 --memory 8 --disk 100
```

- `--memory` is in GiB.
- CPU and memory can be changed later by stopping and starting again with new values.
- Disk size can only be increased, not shrunk.

To make settings permanent, edit the profile config (opens `~/.colima/default/colima.yaml` in your editor):

```bash
colima start --edit
```

### Multiple profiles

You can run separate VMs, for example one per project:

```bash
colima start --profile work --cpu 4 --memory 8
docker context use colima-work
colima stop --profile work
```

## Running x86_64 (amd64) images

Apple Silicon is arm64. Most popular images are multi-arch, but some are amd64 only.

**Option A, Rosetta emulation inside the arm64 VM (fast, recommended):**

```bash
colima start --vm-type vz --vz-rosetta
```

Then run amd64 images with `--platform`:

```bash
docker run --rm --platform linux/amd64 alpine uname -m   # x86_64
```

Rosetta must be installed on the Mac (`softwareupdate --install-rosetta --agree-to-license`).

**Option B, a fully x86_64 VM (slow, uses QEMU):**

```bash
colima start --profile amd64 --arch x86_64
```

Changing `--vm-type` or `--arch` on an existing profile requires `colima delete` first (which wipes its images and containers), so it is usually easier to create a new profile.

## Volumes and file sharing

By default Colima mounts your home directory (`~`) into the VM, read-write. Bind mounts work as long as the host path is under `~`:

```bash
docker run --rm -v "$PWD":/app -w /app alpine ls
```

Paths outside `~` (for example `/Volumes/...` or `/opt/...`) will appear empty in the container. Add them via `colima start --edit` under `mounts:`:

```yaml
mounts:
  - location: ~
    writable: true
  - location: /Volumes/data
    writable: true
```

With `--vm-type vz`, use `--mount-type virtiofs` for the best file-sharing performance.

## Tools that expect /var/run/docker.sock

The Docker CLI uses the `colima` context, but some tools (Testcontainers, some IDE plugins, older SDKs) ignore contexts and look for `/var/run/docker.sock` or `DOCKER_HOST`.

Find the socket path:

```bash
colima status            # shows the socket, usually ~/.colima/default/docker.sock
```

Option 1, export `DOCKER_HOST` in `~/.zshrc`:

```bash
export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
```

Option 2, symlink the default socket path (needs sudo, survives reboots but must be redone if the profile changes):

```bash
sudo ln -sf "$HOME/.colima/default/docker.sock" /var/run/docker.sock
```

For Testcontainers, also set:

```bash
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
export TESTCONTAINERS_RYUK_DISABLED=true   # only if Ryuk fails to start
```

## Removing Docker Desktop leftovers

If Docker Desktop was installed before, remove it and its config references:

```bash
brew uninstall --cask docker-desktop  # or drag Docker.app to the Trash
docker context use colima
docker context rm desktop-linux       # optional, if it exists
```

Check `~/.docker/config.json` for leftovers such as `"credsStore": "desktop"` or `"currentContext": "desktop-linux"` and change them to `osxkeychain` / `colima`.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | Colima is not running (`colima start`), or the wrong context is active (`docker context use colima`). For non-CLI tools see [/var/run/docker.sock](#tools-that-expect-varrundockersock). |
| `error getting credentials - err: exec: "docker-credential-desktop": executable file not found` | Leftover from Docker Desktop. Set `"credsStore": "osxkeychain"` in `~/.docker/config.json`. |
| `docker: 'compose' is not a docker command` | Install `docker-compose` and add `cliPluginsExtraDirs` (see [step 5](#5-docker-compose-and-buildx)). |
| `exec format error` when running a container | The image is amd64 only. Use `--platform linux/amd64` with Rosetta enabled (see [x86_64 images](#running-x86_64-amd64-images)). |
| Bind-mounted directory is empty in the container | The host path is outside `~`. Add it to `mounts:` in `colima start --edit`. |
| Out of disk space in the VM | `docker system prune -a --volumes` to clean up, or recreate with a larger `--disk`. |
| Colima hangs or fails to start | `colima stop --force`, then `colima start`. Logs: `~/.colima/_lima/colima/ha.stderr.log`. As a last resort, `colima delete` and start fresh. |

## Uninstall

```bash
colima delete
brew services stop colima
brew uninstall colima lima docker docker-compose docker-buildx docker-credential-helper
rm -rf ~/.colima ~/.lima
```

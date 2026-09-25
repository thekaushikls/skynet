![Skynet Factory](assets/banner.png)

# Skynet Factory
- Lightweight development environment.
- Containerized workspace for AI CLI tools (Claude Code, Gemini, OpenCode, Codex)

## The `agent` user

Three separate identifiers: `docker ps` shows `skynet`, the hostname is
`sandbox`, the Linux user is `agent`.

The container runs as `agent` (uid 1000), not root — required for Claude
Code's `--dangerously-skip-permissions` to work at all.

`agent` has `sudo`, gated by a password:

- Set `ROOT_PASSWORD` in `.env` and rebuild. A human at a real terminal
  (`docker exec -it`, `skynet.bat`, an attached VS Code terminal) can then
  `sudo` normally.
- An AI agent's Bash tool has no TTY, so `sudo` fails cleanly there instead
  of prompting — it can't escalate on its own.
- Blank `ROOT_PASSWORD` locks the account entirely. `docker exec -u 0 skynet
  <cmd>` from the host always works regardless.
- Build args are visible via `docker history --no-trunc` — fine for a local
  sandbox, not a real secret store.

`git`, `curl`, `nano`, `ca-certificates`, `htop`, `build-essential` are
baked in. Add more in one of two places:

- **System packages** (apt, root, rebuild) — edit the Dockerfile's
  `apt install` line, or `sudo apt install <pkg>` for a one-off (won't
  survive a rebuild).
- **User-scope tools that don't need root** — `uv`, `rust`, `gh`, `bun`,
  `aws`, npm globals, gems, ... — copy
  [scripts/toolchain.local.sh.sample](scripts/toolchain.local.sh.sample)
  to `scripts/toolchain.local.sh` (gitignored), edit, run:

  ```bash
  docker exec skynet bash /scripts/toolchain.local.sh
  ```

  Persists across rebuilds via the `toolchain-*` volumes in
  `docker-compose.override.yml`. Prefer this over the Dockerfile when a tool
  supports it (e.g. `gh`) — no rebuild, no sudo password needed.

### Fixing permissions on pre-existing files

Files created while the container ran as root (or via a later
`docker exec -u 0` session) are root-owned and not writable by `agent`.
If you hit `Permission denied` / `EACCES` on something under `/workspace`
or your Claude session state, fix ownership with:

```bash
# from an interactive shell inside the container
sudo bash /scripts/fix-perms.sh <path>

# or, from the Windows host, no password needed
docker exec -u 0 skynet bash /scripts/fix-perms.sh <path>
```

## Bind Mounts

`WORKSPACE_SOURCE` (host) is bind-mounted to `WORKSPACE_TARGET` (container,
default `/workspace`), both set in `.env`. Changes on either side show up
on the other immediately.

## ENV sample

Create a `.env` file from `.env.sample`:

```env
DISPLAY_BANNER=true
ROOT_PASSWORD=

WORKSPACE_SOURCE=./workspace
WORKSPACE_TARGET=/workspace
```

- `DISPLAY_BANNER`: Purely cosmetic display of ASCII banner on `clear`
- `ROOT_PASSWORD`: Password for `sudo` as the `agent` user (see above). Blank = locked.
- `WORKSPACE_SOURCE`: Local directory to mount
- `WORKSPACE_TARGET`: Mount point inside container

You'll also want a local `docker-compose.override.yml` — copy it from
[docker-compose.override.yml.sample](docker-compose.override.yml.sample).
It's gitignored (for your personal mounts). `docker-compose.yml` builds and
runs fine without it, but you'll lose the `.ssh` mount and persisted
toolchain volumes.

## Usage

### CLI

Start the container using Docker Compose:

```bash
docker-compose up -d
```

Access the running container using the `skynet.bat` or `skynet.sh`.

```bash
skynet.bat
```
```bash
./skynet.sh
```

The script will:
- Check Docker daemon status
- Verify Skynet container is running
- Display npm version
- Launch an interactive bash session (as the `agent` user)

Stop the container:

```bash
docker-compose down
```

### VS Code

With the container running, use **Dev Containers: Attach to Running
Container** and pick `skynet`. Since the image runs as `agent`, VS Code
Server, terminals, and the Claude Code extension all attach as `agent`
automatically — no extra config needed. Attach doesn't manage the
container's lifecycle; `docker-compose down` still stops it.

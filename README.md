![Skynet Factory](assets/banner.png)

# Skynet Factory
- Lightweight development environment.
- Containerized workspace for AI CLI tools (Claude Code, Gemini, OpenCode, Codex)

## The `skynet` user

The container runs as a non-root user, `skynet` (uid 1000) — not `root`.
This is what lets Claude Code's `--dangerously-skip-permissions` work at all;
it refuses to run as root.

`skynet` has `sudo`, but it's gated by a password:

- Set `SKYNET_PASSWORD` in `.env` and rebuild to enable it. A human typing at
  a real terminal (`docker exec -it`, `skynet.bat`, or an attached VS Code
  terminal) can then `sudo` normally.
- An AI agent running inside the container (e.g. Claude Code's Bash tool)
  has no TTY, so `sudo` fails cleanly there instead of prompting — the agent
  cannot escalate to root on its own.
- Leave `SKYNET_PASSWORD` blank and the account is locked — no password-based
  sudo at all. `docker exec -u 0 skynet <cmd>` from the host always works
  regardless, as a Docker-level privilege independent of the password.
- Build args (including `SKYNET_PASSWORD`) are visible via
  `docker history --no-trunc` on the built image — fine for a local sandbox,
  don't reuse this as a real secret elsewhere.

**Toolchain personalization is not implemented yet.** Only `git`, `curl` and
`nano` are baked into the image. Everything else (`gh`, `uv`, `rust`, `bun`,
`nvm`, `aws`, `ruff`, `pnpm`, ...) you install yourself, e.g.:

```bash
docker exec -it skynet bash
sudo apt install -y <package>
```

A declarative way to configure this per-fork is planned but not built.

### Fixing permissions on pre-existing files

Files created while the container ran as root (or via a later
`docker exec -u 0` session) are root-owned and not writable by `skynet`.
If you hit `Permission denied` / `EACCES` on something under `/workspace`
or your Claude session state, fix ownership with:

```bash
# from an interactive shell inside the container
sudo bash /scripts/fix-perms.sh <path>

# or, from the Windows host, no password needed
docker exec -u 0 skynet bash /scripts/fix-perms.sh <path>
```

See [AGENTS.md](AGENTS.md) — it's bind-mounted into the container as
`skynet`'s user-level Claude Code memory, so an agent hitting this will
already know to ask you rather than work around it.

## Bind Mounts

The container uses bind mounts to sync your local workspace with the container filesystem:

- **Host Path**: Defined by `WORKSPACE_SOURCE` in `.env` (e.g., `X:/skynet/workspace`)
- **Container Path**: Defined by `WORKSPACE_TARGET` in `.env` (default: `/workspace`)

All files in your source directory are accessible inside the container at the target path, allowing seamless development with persistent data.

## ENV sample

Create a `.env` file from `.env.sample`:

```env
DISPLAY_BANNER=false
WORKSPACE_SOURCE=./workspace
WORKSPACE_TARGET=/workspace
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_GEMINI=false
INSTALL_OPENCODE=false
SKYNET_PASSWORD=
```

- `DISPLAY_BANNER`: Purely cosmetic display of ASCII banner on `clear`
- `WORKSPACE_SOURCE`: Local directory to mount
- `WORKSPACE_TARGET`: Mount point inside container
- `INSTALL_CLAUDE`: Install Anthropic Claude Code CLI tool
- `INSTALL_CODEX`: Install OpenAI Codex CLI tool
- `INSTALL_GEMINI`: Install Google Gemini CLI tool
- `INSTALL_OPENCODE`: Install OpenCode AI CLI tool
- `SKYNET_PASSWORD`: Password for `sudo` as the `skynet` user (see above). Blank = locked.

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
- Launch an interactive bash session (as the `skynet` user)

Stop the container:

```bash
docker-compose down
```

### VS Code

With the container running (`docker-compose up -d`), use the **Dev
Containers: Attach to Running Container** command and pick `skynet`. Since
the image itself runs as `skynet` (not root), VS Code Server, every
integrated terminal, and the Claude Code extension all attach as `skynet`
automatically — no extra devcontainer config needed for
`--dangerously-skip-permissions` to work inside the extension.

Attach never manages the container's lifecycle, so `docker-compose down`
is still what stops it.

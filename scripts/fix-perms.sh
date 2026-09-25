#!/bin/bash
# Recursively chown a path (or paths) to agent:agent.
#
# Must run as root. Two equivalent ways to invoke it:
#
#   # from an interactive shell inside the container (asks for agent's password)
#   sudo bash /scripts/fix-perms.sh /workspace/SomeRepo
#
#   # from the Windows host, no password needed
#   docker exec -u 0 skynet bash /scripts/fix-perms.sh /workspace/SomeRepo
#
# Only needed for files/directories that were created while the container
# ran as root, before the switch to a non-root `agent` user. New files
# created by `agent` are already owned correctly and don't need this.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "fix-perms.sh must run as root (use sudo, or docker exec -u 0)." >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "Usage: fix-perms.sh <path> [path...]" >&2
    exit 1
fi

for target in "$@"; do
    case "$target" in
    /workspace | /workspace/* | /home/agent | /home/agent/*) ;;
    *)
        echo "Refusing to chown '$target': only paths under /workspace or /home/agent are allowed." >&2
        exit 1
        ;;
    esac

    if [ ! -e "$target" ]; then
        echo "Skipping '$target': does not exist." >&2
        continue
    fi

    echo "==> chown -R agent:agent $target"
    chown -R agent:agent "$target"
done

echo "Done."

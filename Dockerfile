FROM node:24-bookworm-slim

ARG DISPLAY_BANNER=true
ARG SKYNET_PASSWORD

RUN apt update && apt upgrade -y

# Baseline system packages. Other tools can be installed
# via `sudo apt install [PACKAGE-NAME]`
RUN apt install -y sudo curl git nano ca-certificates

# Rename the stock `node` user (uid/gid 1000) to `skynet` rather than adding
# a second user, so it inherits a working home and there's no uid collision.
RUN groupmod -n skynet node \
    && usermod -l skynet -d /home/skynet -m -s /bin/bash node \
    && usermod -aG sudo skynet

# Password-gated sudo: `skynet` can become root, but only a human
# typing the password at a real terminal can do it. Claude Code's Bash tool
# runs non-interactively with no TTY, so `sudo` fails cleanly there instead
# of prompting - the agent cannot escalate on its own. The password is a
# build-time-only ARG: it lands in `/etc/shadow`, never in a runtime env var,
# so nothing running inside the container can read it back out.
# Leaving SKYNET_PASSWORD unset locks the account (no password-based sudo at
# all); `docker exec -u 0` from the host is always available regardless.
RUN if [ -n "$SKYNET_PASSWORD" ]; then \
    echo "skynet:${SKYNET_PASSWORD}" | chpasswd; \
    else \
    passwd -l skynet; \
    fi

# npm global prefix owned by `skynet`, so global installs (and Claude Code's
# own auto-update) work without root.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:/home/skynet/.local/bin:$PATH
RUN mkdir -p $NPM_CONFIG_PREFIX && chown -R skynet:skynet /usr/local/share

# Pre-create and chown home + future volume mount points before switching
# USER - a fresh named volume inherits ownership from whatever already
# exists at its mount path in the image, so this is what stops bind/volume
# mounts coming back root-owned.
RUN mkdir -p /home/skynet/.local /home/skynet/.claude /home/skynet/.ssh \
    && chown -R skynet:skynet /home/skynet

USER skynet

# Update npm
RUN npm install -g npm@latest

# AI CLI tools (Claude Code, etc.) are not installed by default - install
# them yourself with `npm install -g <package>` once toolchain personalization
# is designed. See README.md.

# Setup terminal banner if requested
COPY --chown=skynet:skynet scripts/add_banner.sh /tmp/add_banner.sh
RUN if [ "$DISPLAY_BANNER" = "true" ]; then \
    chmod +x /tmp/add_banner.sh && \
    /tmp/add_banner.sh && \
    rm /tmp/add_banner.sh; \
    fi

WORKDIR /workspace

FROM node:24-bookworm-slim

ARG DISPLAY_BANNER=true
ARG ROOT_PASSWORD

RUN apt update && apt upgrade -y

# Baseline packages - see README.md for how to add more.
RUN apt install -y sudo curl git nano ca-certificates htop build-essential

# Rename the stock `node` user (uid/gid 1000) to `agent` - inherits a
# working home, no uid collision.
RUN groupmod -n agent node \
    && usermod -l agent -d /home/agent -m -s /bin/bash node \
    && usermod -aG sudo agent

# Password-gated sudo: agent's Bash tool has no TTY, so `sudo` fails
# cleanly instead of prompting - it can't escalate on its own. A human at a
# real terminal can. Blank ROOT_PASSWORD locks the account entirely.
RUN if [ -n "$ROOT_PASSWORD" ]; then \
    echo "agent:${ROOT_PASSWORD}" | chpasswd; \
    else \
    passwd -l agent; \
    fi

# npm global prefix owned by agent, so global installs work without root.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:/home/agent/.local/bin:$PATH
RUN mkdir -p $NPM_CONFIG_PREFIX && chown -R agent:agent /usr/local/share

# Pre-chown before USER switch - a fresh named volume mounted here later
# inherits this ownership instead of coming back root-owned.
RUN mkdir -p /home/agent/.local /home/agent/.claude /home/agent/.ssh \
    && chown -R agent:agent /home/agent

USER agent

RUN npm install -g npm@latest

# AI CLI tools aren't installed by default - see README.md /
# scripts/toolchain.local.sh.sample.

COPY --chown=agent:agent scripts/add_banner.sh /tmp/add_banner.sh
RUN if [ "$DISPLAY_BANNER" = "true" ]; then \
    chmod +x /tmp/add_banner.sh && \
    /tmp/add_banner.sh && \
    rm /tmp/add_banner.sh; \
    fi

WORKDIR /workspace

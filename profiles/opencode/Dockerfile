ARG BASE_IMAGE=dwork-base:latest
FROM ${BASE_IMAGE}

# Install OpenCode into the image (not into the persistent home volume).
RUN curl -fsSL https://opencode.ai/install | bash \
    && sudo install -m 0755 "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode \
    && rm -rf "$HOME/.opencode" \
    && opencode --version

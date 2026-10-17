ARG BASE_IMAGE=dwork-base:latest
FROM ${BASE_IMAGE}

# OpenCode 2. Override with: dwork build opencode --build-arg OPENCODE_VERSION=x.y.z
ARG OPENCODE_VERSION=2.0.32

# Install into the image (not into the persistent home volume).
RUN curl -fsSL https://opencode.ai/v2/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path \
    && sudo install -m 0755 "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode \
    && rm -rf "$HOME/.opencode" \
    && opencode --version

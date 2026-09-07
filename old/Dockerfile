
FROM debian:bookworm-slim

ARG UID
ARG GID

# Create non-root hostuser
RUN groupadd --gid $GID hostuser && \
    useradd --uid $UID --gid $GID hostuser

# Install basic set of tools
RUN apt-get update && apt-get install -y \
    make cmake git unzip wget python3 curl build-essential gcc g++ sudo jq \
    && apt-get clean

# Setup folders to use by hostuser
RUN mkdir -p /home/hostuser && chown hostuser:hostuser /home/hostuser

# Let hostuser have password free sudo abilities:
RUN echo "hostuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hostuser && \
    chmod 0440 /etc/sudoers.d/hostuser

ENV HOME=/home/hostuser

USER hostuser

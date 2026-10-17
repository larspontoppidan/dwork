ARG BASE_IMAGE=dwork-base:latest
FROM node:24-bookworm-slim AS node
FROM ${BASE_IMAGE}

# Pi is an interactive terminal coding harness. Install it into the image;
# configuration, provider logins, packages and sessions remain in the
# persistent /home/hostuser volume.
# Override with: dwork build pi --build-arg PI_VERSION=x.y.z
ARG PI_VERSION=1.3.0
USER root
COPY --from=node /usr/local/ /usr/local/
RUN npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    && npm cache clean --force \
    && pi --version
USER hostuser

ARG BASE_IMAGE=dwork-x11:latest
FROM ${BASE_IMAGE}

# ZCode, the Z.ai desktop app (Electron). Official Linux .deb from Z.ai's CDN.
# Override with: dwork build zcode --build-arg ZCODE_VERSION=x.y.z
ARG ZCODE_VERSION=3.15.3
ARG TARGETARCH
# "Connect to Z.ai" signs in through the system browser, so ship one on the
# virtual desktop. Build with --build-arg WITH_BROWSER=0 to leave it out and use
# the "Use API key" option instead.
ARG WITH_BROWSER=1

USER root
RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    url="https://cdn-zcode.z.ai/zcode/electron/releases/${ZCODE_VERSION}/linux-${arch}/ZCode-${ZCODE_VERSION}-linux-${arch}.deb"; \
    echo "Downloading $url"; \
    curl -fsSL -o /tmp/zcode.deb "$url"; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/zcode.deb fonts-noto-cjk; \
    if [ "$WITH_BROWSER" = 1 ]; then apt-get install -y --no-install-recommends firefox-esr; fi; \
    rm -f /tmp/zcode.deb; \
    apt-get clean; rm -rf /var/lib/apt/lists/*; \
    test -x /opt/ZCode/zcode

ENV BROWSER=firefox-esr
USER hostuser

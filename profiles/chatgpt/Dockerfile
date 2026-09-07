ARG BASE_IMAGE=dwork-x11:latest
FROM ${BASE_IMAGE}

# Official ChatGPT Linux .deb (ChatGPT + Work + Codex). OpenAI's latest/ URL
# always points at the current release. Docker may cache this RUN; rebuild with
# --build-arg CHATGPT_REFRESH=$(date +%s) to force a new download.
ARG TARGETARCH
ARG CHATGPT_REFRESH=0
# Sign-in opens the system browser. Build with --build-arg WITH_BROWSER=0 to
# skip Firefox if you only use API-key login.
ARG WITH_BROWSER=1

COPY wrap-chatgpt /usr/local/sbin/wrap-chatgpt

USER root
RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
      amd64) debarch=amd64 ;; \
      arm64) debarch=arm64 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_${debarch}.deb"; \
    echo "Downloading $url (refresh=$CHATGPT_REFRESH)"; \
    curl -fsSL -o /tmp/chatgpt.deb "$url"; \
    apt-get update; \
    apt-get install -y --no-install-recommends /tmp/chatgpt.deb bubblewrap; \
    if [ "$WITH_BROWSER" = 1 ]; then apt-get install -y --no-install-recommends firefox-esr; fi; \
    rm -f /tmp/chatgpt.deb; \
    apt-get clean; rm -rf /var/lib/apt/lists/*; \
    chmod 0755 /usr/local/sbin/wrap-chatgpt; \
    /usr/local/sbin/wrap-chatgpt; \
    test -x /usr/bin/chatgpt; \
    test -x /usr/lib/chatgpt/ChatGPT.bin

ENV BROWSER=firefox-esr \
    ELECTRON_DISABLE_SANDBOX=1 \
    ELECTRON_OZONE_PLATFORM=x11
USER hostuser

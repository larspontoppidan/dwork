# dwork-base: long-lived "pet" container foundation.
#
# - hostuser matches the host UID/GID so bind-mounted files keep their owner
# - passwordless sudo, so `apt install` works from an interactive shell
# - supervisord is PID 1; the application is a supervised program, so the
#   container (and shell access) survives application crashes and restarts
FROM debian:bookworm-slim

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg \
        git make cmake build-essential gcc g++ pkg-config \
        python3 python3-pip python3-venv \
        unzip zip xz-utils jq less vim-tiny nano tmux \
        procps psmisc iproute2 iputils-ping dnsutils net-tools \
        openssh-client rsync sudo \
        supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "$GID" hostuser \
    && useradd --uid "$UID" --gid "$GID" --create-home --shell /bin/bash hostuser \
    && echo "hostuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hostuser \
    && chmod 0440 /etc/sudoers.d/hostuser \
    && mkdir -p /work /run/dwork /var/log/dwork \
    && chown hostuser:hostuser /work /run/dwork /var/log/dwork

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY conf.d/ /etc/supervisor/conf.d/
COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/dwork-*

# Runtime contract (overridden per instance through docker compose):
#   DWORK_APP_CMD        shell command line for the supervised "app" program
#   DWORK_APP_AUTOSTART  true|false, whether "app" starts with the container
ENV HOME=/home/hostuser \
    DWORK_APP_CMD="" \
    DWORK_APP_AUTOSTART=false

USER hostuser
WORKDIR /home/hostuser

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# dwork-x11: virtual X11 desktop exposed through VNC.
#
#   Xtigervnc  X server + VNC server in one process, display :1
#   openbox    minimal window manager
# Xvnc listens on all container interfaces so Docker can publish the VNC port.
# The host mapping is 127.0.0.1 (see dwork create --vnc-port); there is no VNC password.
#
# The application runs on the same display, so anything started from an
# interactive shell (DISPLAY is preset) also shows up on the VNC desktop.
# The lib* packages are the usual Electron/Chromium runtime dependencies.
ARG BASE_IMAGE=dwork-base:latest
FROM ${BASE_IMAGE}

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        tigervnc-standalone-server tigervnc-tools \
        openbox xterm x11-utils x11-xserver-utils xdg-utils \
        dbus-x11 at-spi2-core \
        fonts-dejavu fonts-liberation fonts-noto-core \
        libgtk-3-0t64 libnss3 libasound2t64 libxss1 libgbm1 libxshmfence1 libdrm2 \
        libatk-bridge2.0-0t64 libcups2t64 libnotify4 libsecret-1-0 libxkbfile1 libfuse2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix \
    && mkdir -p /run/dwork/xdg && chown hostuser:hostuser /run/dwork/xdg && chmod 700 /run/dwork/xdg

COPY conf.d/ /etc/supervisor/conf.d/
COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/dwork-*

ENV DISPLAY=:1 \
    DWORK_GEOMETRY=1920x1080 \
    DWORK_VNC_PORT=5901 \
    XDG_RUNTIME_DIR=/run/dwork/xdg \
    NO_AT_BRIDGE=1

USER hostuser

# dwork

Containerized "pet" workspaces for a headless Linux server. One CLI creates
long-lived Docker containers that run either a **web app** (OpenCode), an **X11
app** on a virtual desktop exposed through VNC (ZCode, the Z.ai desktop
app), or nothing at all (a plain **shell** box). Every instance:

- runs as a user with your host UID/GID, so bind-mounted files keep their owner
- has passwordless `sudo` and a Debian 13 (trixie) toolchain, so you can `apt install`
  and poke around with `dwork bash NAME`
- keeps its `$HOME` in a named Docker volume and mounts any number of host
  directories under `/work/...`
- stays up even if the application crashes: `supervisord` is PID 1 and the app
  is a supervised program you can restart from inside or outside
- web instances are reachable through one shared nginx proxy with TLS and HTTP
  basic auth at `https://NAME.localhost:4443`; X11 instances are a VNC desktop
  on `127.0.0.1:5901`

## Quick start

```sh
# optional: put the CLI on your PATH
ln -s "$PWD/dwork" ~/.local/bin/dwork

dwork profiles
dwork create zc --profile zcode --mount ~/proj              # X11 app over VNC on 127.0.0.1:5901
dwork create oc --profile opencode --mount ~/proj --port 14096   # web app (+ direct port)
dwork create box --profile shell --mount ~/proj --mount ~/data:/data

dwork status
dwork url zc
dwork bash zc
```

For web profiles, `create` prompts once for a password. That login protects the
proxy vhost and, for profiles that support it (OpenCode), is also handed to the
application so a single login works end to end.

X11 instances publish TigerVNC on `127.0.0.1:5901` (override with `--vnc-port`).
There is no VNC password; the bind is localhost-only. From your workstation:

```sh
ssh -N -L 5901:127.0.0.1:5901 user@server
# then connect a VNC client to 127.0.0.1:5901
```

The shared HTTPS proxy (web apps only) binds to `127.0.0.1:4443` by default:

```sh
ssh -N -L 4443:127.0.0.1:4443 user@server
# then open https://oc.localhost:4443 (browsers resolve *.localhost to 127.0.0.1)
```

Set `DWORK_PROXY_BIND=0.0.0.0` (and ideally `DWORK_DOMAIN=myserver.lan`, which
adds `NAME.myserver.lan` to the certificates) to expose it on a LAN/VPN
interface instead. The vhost matches `NAME.*`, so any suffix works.

## Commands

| Command | What it does |
| --- | --- |
| `create NAME --profile P [--mount H[:C]]... [--port N] [--vnc-port N] [--no-vnc] [--no-proxy] [--user U] [--geometry WxH] [--app-cmd CMD]` | build images, write the instance, start it (web: add the HTTPS proxy) |
| `start` / `stop` / `restart NAME` | container lifecycle (`restart` also picks up rebuilt images and edits to `compose.yaml`) |
| `bash NAME [CMD...]` | interactive shell inside (starts the container if needed) |
| `app NAME start\|stop\|restart\|status` | control the supervised application |
| `logs NAME [PROGRAM]` | follow logs; programs: `app`, and for x11 `xvnc`, `openbox` |
| `url NAME` | print the URLs and the ssh tunnel command |
| `status` | list instances and the proxy |
| `rm NAME [--purge]` | remove the instance; the home volume is kept unless `--purge` |
| `edit NAME` | open the instance `compose.yaml` in `$EDITOR` |
| `build PROFILE [--pull] [--build-arg K=V]` | (re)build base, x11 and profile images |
| `proxy add\|rm\|passwd NAME`, `proxy reload\|status\|logs` | manage the shared nginx |

Inside a container the same controls exist: `supervisorctl status`,
`supervisorctl restart app`, `supervisorctl tail -f app`. In X11 containers
`DISPLAY=:1` is preset, so `xterm &` from `dwork bash` shows up on the desktop.

## How it fits together

```
images/base    Debian 13 + hostuser(UID/GID) + sudo + tools + supervisord (PID 1)
images/x11     + Xtigervnc (X server & VNC server, display :1, published on the host)
               + openbox + Electron/GTK runtime libs
profiles/P     Dockerfile (optional) + profile.env describing the app
```

Each instance is a small docker compose project generated into
`~/.config/dwork/instances/NAME/`:

- `compose.yaml` – the container definition. Edit freely (extra mounts,
  devices, env vars…) and run `dwork restart NAME`.
- `.env` – settings referenced by the compose file and by the CLI.
- `secrets.env` – credentials passed to the container (mode 600).

The proxy is another compose project in `~/.config/dwork/proxy/` with one
generated vhost, self-signed certificate and htpasswd file per web instance. All
containers share the `dwork-web` Docker network; nginx resolves `NAME` at
request time, so instances can be down without breaking the proxy config.

Access paths:

```
VNC client ──▶ 127.0.0.1:5901 ──▶ NAME:5901 (x11: Xtigervnc, no password)
browser ──https+auth──▶ nginx ──http──▶ NAME:4096   (web: the app itself)
```

## Profiles

A profile is a directory under `profiles/` with a `profile.env` and, if the
image needs anything installed, a `Dockerfile` that starts with
`ARG BASE_IMAGE` / `FROM ${BASE_IMAGE}`.

```sh
# profiles/opencode/profile.env
DWORK_KIND=web                      # x11 | web | shell
DWORK_DESCRIPTION="OpenCode web UI"
DWORK_HTTP_PORT=4096                # what nginx proxies to (web only)
DWORK_APP_CMD="opencode web --hostname 0.0.0.0 --port 4096"
DWORK_AUTH_USER_ENV=OPENCODE_SERVER_USERNAME   # optional: feed the proxy login
DWORK_AUTH_PASS_ENV=OPENCODE_SERVER_PASSWORD   #           to the app as env vars
```

Included profiles:

- `shell` – plain dev box, no service.
- `opencode` – OpenCode web UI, installed into the image.
- `zcode` – ZCode (Z.ai desktop app, Electron) from the official Linux `.deb`,
  started with `--no-sandbox --disable-gpu`. Ships Firefox so the "Connect to
  Z.ai" browser login can complete on the virtual desktop (`--build-arg
  WITH_BROWSER=0` to skip it and use an API key). Pin a version with
  `dwork build zcode --build-arg ZCODE_VERSION=x.y.z`.
- `chatgpt` – official ChatGPT desktop app (ChatGPT, Work, and Codex) from
  OpenAI's `latest/` Linux `.deb`. Same Electron flags and optional Firefox
  for account sign-in. Force a fresh download with
  `dwork build chatgpt --build-arg CHATGPT_REFRESH=$(date +%s)`.
  Codex agent jobs that use bubblewrap may need extra Docker privileges.

To add another X11 app: create `profiles/foo/Dockerfile` that `apt`s or unpacks
it, set `DWORK_KIND=x11` and `DWORK_APP_CMD` in `profile.env`, done. Electron
apps generally need `--no-sandbox`; the compose file already sets
`shm_size: 1g` for x11 instances.

## Notes

- Images are tagged `dwork-*:UID-GID`; run `dwork` as the user whose files you
  mount, not as root.
- After `dwork build P`, `dwork restart NAME` recreates the container from the
  new image. Home volumes and mounts are untouched.
- Certificates are self-signed (`~/.config/dwork/proxy/certs/NAME.crt`);
  import one into your browser's trust store to silence the warning, or replace
  the pair with a real certificate and run `dwork proxy reload`.
- VNC is published on `127.0.0.1` with no password. Do not change the bind to
  `0.0.0.0` unless you add VNC authentication first. Use `--vnc-port` when you
  have more than one X11 instance.
- `DWORK_HOME` moves the state directory (default `~/.config/dwork`).

The previous generation of scripts lives in `old/` for reference.

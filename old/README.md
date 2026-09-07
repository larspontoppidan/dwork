# dwork

Small persistent development containers that use the host user's UID and GID.

## Generic pet container

```sh
./dwork-create.sh NAME /path/to/work
docker start NAME
./dwork-bash.sh NAME
```

The container runs `sleep infinity`; interactive shells can come and go without
stopping it.

## OpenCode pet container

```sh
./dwork-create-opencode.sh NAME /path/to/work
```

This builds OpenCode into a specialized image and starts it as the container's
main service. Choose a localhost port and open:

```text
http://localhost:4096
```

The script prints the command for optionally adding the shared Nginx HTTPS
proxy afterward. Once configured, open:

```text
https://NAME.localhost:4443
```

Nginx is shared by all proxied OpenCode pets. The selected direct port remains
available only on `127.0.0.1`. The selected work directory is mounted as
`/home/hostuser`, so it is visible in OpenCode's folder picker and also stores
OpenCode's home-directory state.

Passwords, generated Nginx configuration, and local certificates are kept in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dwork
```

The creation script prompts for the OpenCode username and password; the
username defaults to `opencode`. The resulting credentials are saved in the
instance's `.env` file in the `secrets` directory.

The generated TLS certificate is self-signed. Import the instance's `.crt`
file from the `nginx/certs` directory into the local trust store to remove the
browser warning. It can be replaced with a certificate for the same hostname;
then reload the proxy with:

```sh
docker exec dwork-nginx nginx -s reload
```

Modern browsers normally resolve names below `.localhost` to `127.0.0.1`. If
your resolver does not, add the instance explicitly to `/etc/hosts`, for
example:

```text
127.0.0.1 myproject.localhost
```

Set a different shared HTTPS port before creating the first instance:

```sh
DWORK_HTTPS_PORT=8443 ./dwork-create-opencode.sh NAME /path/to/work
```

Nginx can also be added later to an existing OpenCode pet that was created
without it:

```sh
./dwork-setup-nginx.sh NAME
```

Use `./dwork-bash.sh NAME` for an interactive shell and `docker logs NAME` for
the OpenCode server log.

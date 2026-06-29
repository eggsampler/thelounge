# Deploying this fork (Docker + an external Cloudflare Tunnel)

Runs The Lounge from the CI-built image (`ghcr.io/eggsampler/thelounge`) and
serves it through a Cloudflare Tunnel that you run **on the host**, so this stack
exposes nothing publicly.

```
[browser] --TLS--> [Cloudflare edge] --tunnel--> [host cloudflared] --http--> 127.0.0.1:9000
```

## 1. Start The Lounge

```sh
# if the GHCR package is private, run `docker login ghcr.io` first
docker compose pull
docker compose up -d

# create your login (private instance, no public signup)
docker compose exec thelounge node index.js add <username>
```

The container binds `127.0.0.1:9000` only, so it is not reachable from outside the host.

## 2. Point your host cloudflared at it

With `cloudflared` installed as a host service, add a **Public Hostname** to your
tunnel in the Cloudflare Zero Trust dashboard:

- Hostname: `<your-hostname>`
- Service: **HTTP** → `http://localhost:9000`

That also creates the proxied DNS record. TLS is terminated at Cloudflare's edge
(Universal SSL), so there are no certificates to manage here.

## Restoring from a backup

To seed the volume from a backup of an existing `THELOUNGE_HOME` (config, users,
logs + sqlite history, uploads) instead of creating a fresh user, load it into the
volume. The `rm` line drops installed packages and the web-push keys; remove it to
keep them.

```sh
docker compose up -d
docker compose stop thelounge          # don't write while we swap the data in

# extract the tarballs into the named volume via a throwaway container,
# then fix ownership (the container runs as uid/gid 1000 = the node user)
docker run --rm --volumes-from thelounge -v /path/to/backups:/b:ro alpine sh -c '
  cd /var/opt/thelounge &&
  for f in /b/*.tar.gz; do tar xzf "$f"; done &&
  rm -rf packages vapid.json &&
  chown -R 1000:1000 /var/opt/thelounge
'

docker compose start thelounge
docker compose logs -f thelounge
```

A fresh `vapid.json` is regenerated on start. If the backup's `config.js` pins
`host` to `127.0.0.1`, the `host=0.0.0.0` override in the compose `command:`
keeps it reachable.

## 3. Updating

CI rebuilds the image on every push. To roll out an update:

```sh
docker compose pull && docker compose up -d
```

For reproducible deploys, pin a specific tag (CI also publishes a `sha-…` tag per
build) instead of `latest`.

## Notes

- `reverseProxy=true` (set in the compose `command:`) makes The Lounge trust the
  `X-Forwarded-*` headers from the tunnel.
- Data (config, logs, sqlite history, uploads) persists in the `thelounge-data`
  volume at `/var/opt/thelounge`.
- The clickable-highlights feature relies on message history, which is on by
  default (`messageStorage: ["sqlite", "text"]`, `maxHistory: 10000`).

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

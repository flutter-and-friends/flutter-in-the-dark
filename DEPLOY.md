# fitd26 event deployment

One command on the event host:

```bash
docker compose up -d
```

…brings up the whole stack (WI-100 host split):

- **App SPA** on the apex **`https://flutterinthedark.dev`** — the public
  URL contestants/audience open.
- **API** on **`https://backend.flutterinthedark.dev`** — the room-state
  service + the dart_services generation backend. The app calls this
  **cross-origin** (CORS is wired on both backends).

```
                         internet / venue Wi-Fi                tailnet (admin phone)
                                  │                                  │
                      80/443 ─────▼──────────────        100.x:4443 ──▼──────────────
                      ┌─────────────────────────┐        ┌──────────────────────────┐
                      │  PUBLIC entrypoint      │        │  TAILSCALE entrypoint     │
                      │  websecure (ACME TLS)   │        │  (tailscale-issued cert)  │
                      │                         │        │                           │
                      │  apex flutterinthedark  │        │  FULL SPA incl. /admin    │
                      │    .dev: / /show+static │        │  /api/* incl. /api/admin/*│
                      │  backend.flutterinthe-  │        │  dart_services API        │
                      │    dark.dev: room +     │        │                           │
                      │    dart_services API    │        │  (gate is STRUCTURAL:     │
                      │                         │        │   admin routes simply do  │
                      │  NO route to /admin or  │        │   not exist on either     │
                      │  /api/admin/*  → 404    │        │   public host :443)       │
                      └───────────┬─────────────┘        └─────────────┬────────────┘
                                  └────────────────┬───────────────────┘
                        ┌──────────────────────────┼──────────────────┐
                        ▼                          ▼                  ▼
                   app (nginx,              room (Dart shelf,   dart_services
                   release SPA,             in-memory room +   (generation +
                   SPA fallback)            SSE + pipeline)    compile, Berget)
                        :80                      :8302               :8300
```

### Host layout (WI-100, 2026-08-19)

| Host | Serves | Exposure |
|---|---|---|
| `flutterinthedark.dev` (apex) | App SPA: `/`, `/show` + static assets (`/assets`, `/canvaskit`, `/icons`, `*.js`, …) | public (ACME TLS) |
| `backend.flutterinthedark.dev` | API: room (`/api/state` `/api/events` `/api/join` `/api/prompt` `/api/probe-generate`) + dart_services (`/api/v3/generateCode` `/compileAndServe` `/suggestFix`, `/compiled/*`, `/artifacts/*`) | public (ACME TLS) |
| `<machine>.<tailnet>.ts.net:4443` | full SPA incl. `/admin` + full API incl. `/api/admin/*` | tailnet only |

### Cross-origin (CORS) wiring

The app on the apex calls the API on `backend.*` — a different origin.
This is wired, not incidental:

- The release build bakes `--dart-define=ROOM_URL=https://backend.flutterinthedark.dev`
  and `--dart-define=DART_SERVICES_URL=…` (see `deploy/Dockerfile.app`), so
  `RoomClient` resolves both the room API base AND the compiled-widget
  iframe base (`/compiled/<id>`) to the backend host.
- The **room service** answers CORS on every route
  (`Access-Control-Allow-Origin: *`, OPTIONS preflight handled, SSE
  `/api/events` carries the header and streams cross-origin — EventSource
  is CORS-enabled and sends no credentials, so `*` is valid).
- **dart_services** sets `Access-Control-Allow-Origin: *` on API JSON and
  `/compiled/*` responses, and the fork clears the default
  `X-Frame-Options: SAMEORIGIN` (WI-093) — the `/compiled/<id>` iframes
  embed cross-origin from the apex. `*` is kept deliberately: this is a
  public, unauthenticated, event-scale generation API. Decision noted
  (WI-100).
- **Tailnet alias**: `RoomClient` resolves same-origin whenever the page
  hostname ends in `.ts.net` — the `:4443` proxy fronts app + full API on
  one origin, so the admin phone keeps working with the same single image.

## The /admin gate (WI-093 D2, confirmed 2026-08-19; unchanged by WI-100)

The gate is **structural, not a middleware rule.** The room service has **no
app-level auth** on admin routes by design — the network boundary IS the auth.

- **Public `:443`** (apex AND backend subdomain) has routers only for `/`,
  `/show`, static assets, the read/contestant API (`/api/state`
  `/api/events` `/api/join` `/api/prompt`), and the dart_services API.
  There is **no router** for `/admin` or `/api/admin/*` → Traefik returns
  its built-in **404** on BOTH public hosts. The route does not exist.
- **Tailnet `:4443`** (published only on the host's `tailscale0` 100.x
  address) carries the **full** SPA incl. `/admin` and the **full** API incl.
  `/api/admin/*`. Only devices on the tailnet (the admin phone) can reach it.

The admin page loading publicly but its actions failing is **not** the
mechanism here — the page itself 404s publicly too (defense in depth). Both
directions are verified (see *Verification* below).

**Fallback if the tailnet is flaky at the venue:** expose `/admin` on the
public domain behind Traefik basic-auth. Commented labels are already in
`docker-compose.yml` under the `app` service — uncomment, set
`BASIC_AUTH_USERS` (htpasswd) in `.env`, and mirror the router for
`/api/admin/*` on the room service. The shipped config does NOT do this.

## Prerequisites (operator, before `up`)

1. **DNS** — point A records for BOTH `flutterinthedark.dev` (apex) AND
   `backend.flutterinthedark.dev` at the event host's public IP. Both must
   be reachable on :80/:443 — Traefik's per-router certresolver issues a
   cert per host via HTTP-01. (The IP is "static-ish"; if it ever changes,
   update the records — dynamic DNS is out of scope, just re-point them.)
2. **Firewall** — allow inbound **80** and **443**. Port 80 is required for
   the ACME HTTP-01 challenge *and* redirects to 443.
3. **Secrets file** — create `deploy/env/dart_services.env` from
   `deploy/env/dart_services.env.example` and set `BERGET_REFRESH_TOKEN`.
   **Verify blind — never print the value** (W-083/W-149):
   ```bash
   [ -f deploy/env/dart_services.env ] && echo exists
   grep -q '^BERGET_REFRESH_TOKEN=' deploy/env/dart_services.env && echo key-present
   chmod 600 deploy/env/dart_services.env
   ```
   Optional keys in the same file: `BERGET_MODEL` (default
   `openai/gpt-oss-120b`), `BERGET_API_URL` (default `https://api.berget.ai`).
4. **Tailscale** —
   - Get the host's tailnet IPv4: `export TAILSCALE_IP=$(tailscale ip -4)`.
   - Enable HTTPS certs in the tailnet admin console (DNS → HTTPS
     Certificates), then issue the machine cert:
     ```bash
     mkdir -p ~/.tailscale-certs && cd ~/.tailscale-certs
     tailscale cert "$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
     # rename the emitted <machine>.<tailnet>.ts.net.{crt,key} to:
     #   tailscale.crt  tailscale.key
     ```
     (`deploy/traefik/tls.yml` reads `/certs/tailscale.{crt,key}`; the host
     dir is overridable via `TAILSCALE_CERT_DIR`.)
5. **Environment** — in `.env` next to `docker-compose.yml` (or exported):
   ```
   DOMAIN=backend.flutterinthedark.dev      # the API host
   APP_DOMAIN=flutterinthedark.dev          # the apex — serves the app SPA
   TAILNET_DOMAIN=<machine>.<tailnet>.ts.net
   ACME_EMAIL=<you@example.com>
   TAILSCALE_IP=<100.x from step 4>
   # optional overrides:
   # BERGET_MODEL=openai/gpt-oss-120b
   # TAILSCALE_CIDR=100.64.0.0/10   (only if the tailnet uses a subnet router)
   # DART_PAD_PATH=../dart-pad      (where the berget-backend checkout lives)
   ```

## The one command

```bash
docker compose up -d
```

First run builds three images (app, room, dart_services). The dart_services
build is the slow one (~15–25 min: Flutter SDK + grind-built `artifacts/` and
`project_templates/`, ~259 MB). To pre-build it on a faster machine and ship
the image:

```bash
cd <dart-pad checkout>/pkgs/dart_services
docker build -f <fitd-repo>/deploy/Dockerfile.dart-services -t fitd26-dart-services:local .
docker save fitd26-dart-services:local | ssh <event-host> docker load
# then on the event host: docker compose up -d  (uses the loaded image, no rebuild)
```

## Verification (from an external client, not inside a container)

Run these from a laptop NOT on the tailnet. App checks hit the apex
(`https://flutterinthedark.dev`), API checks hit
`https://backend.flutterinthedark.dev`:

| Check | apex | backend.* | Tailnet (`:4443`) |
|---|---|---|---|
| `GET /` , `GET /show` | **200** (SPA) | 404 (no app router) | 200 |
| static (`/main.dart.js`, `/manifest.json`) | **200** | 404 | 200 |
| `GET /api/state` | 404 (no API router) | **200** | 200 |
| `GET /api/events` (SSE) | 404 | **200**, streams | 200 |
| `POST /api/join` | 404 | **200** | 200 |
| `POST /api/admin/*` | **404** | **404** | 200 |
| `GET /admin` | **404** | **404** | 200 (SPA) |

Cross-origin app→API (what the apex SPA actually does):

```bash
# CORS preflight for a contestant POST, from the apex origin:
curl -i -X OPTIONS https://backend.flutterinthedark.dev/api/join \
  -H 'Origin: https://flutterinthedark.dev' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type'
# → 200 with Access-Control-Allow-Origin covering the apex.

# The actual GET carries the CORS header on the response:
curl -i https://backend.flutterinthedark.dev/api/state \
  -H 'Origin: https://flutterinthedark.dev'
# → 200 + Access-Control-Allow-Origin.

# A compiled widget iframe, fetched as the apex page will embed it:
curl -i https://backend.flutterinthedark.dev/compiled/<id> \
  -H 'Origin: https://flutterinthedark.dev'
# → 200, Access-Control-Allow-Origin: *, and NO X-Frame-Options.
```

The real browser check (per W-162: bundle-greps and curls are not proof):
open `https://flutterinthedark.dev/`, join, and watch the Network tab —
`/api/state`, `/api/events`, `/api/join`, `/api/prompt` go to
`backend.flutterinthedark.dev` and succeed from the apex origin.

SSE must **stream** (first frame within ~1 s, connection stays open):
```bash
curl -sN https://backend.flutterinthedark.dev/api/events
```
Traefik flushes SSE by default; the room also sends `X-Accel-Buffering: no`.

The authoritative end-to-end gate + loop verification for this stack
(join → prompt → buzzer → generate+compile → tri-state reveal) is scripted at
`scratch/fitd26-deploy/e2e_loop.py` and the routing mirror at
`scratch/fitd26-deploy/proxy_verify.py` (used to verify on a host without
Docker). On the real host, the equivalent is: open `/` on a phone, join, and
watch `/show`.

## Pre-event checklist

- [ ] **Berget token soak test** — the refresh-token → bearer flow over
      *hours* is still unobserved (I-347/I-358). Boot the stack the day
      before, run a few generations at intervals, confirm no auth expiry.
- [ ] **Real-device typing (SHADOW-038)** — human typing into the prompt
      editor on a physical phone is unverified (only MCP-driven entry tested).
      Type a real prompt on the actual contestant devices beforehand.
- [ ] **Re-post-storm (SHADOW-038)** — the re-post-storm fix lacks
      network-level proof on a live window. Watch the network tab during a
      real prompt session.
- [ ] **Concurrent-generation smoke** — 4-way concurrent generation holds on
      STABLE-tier models (worst-case room wait ~45 s on gpt-oss, zero 503s;
      I-358). Re-confirm with the production model before doors.
- [ ] **Tailscale path** — from the admin phone on the tailnet, load
      `https://<machine>.<tailnet>.ts.net:4443/admin` and fire one
      `/api/admin/*` action. (WI-100: the app resolves the API same-origin
      on `*.ts.net`, so this keeps working with the single image.)
- [ ] **ACME first issuance** — hit BOTH `https://flutterinthedark.dev/`
      and `https://backend.flutterinthedark.dev/` and confirm valid Let's
      Encrypt certs for each (check `docker compose logs traefik` for
      challenge errors the first time — both hosts need DNS + :80).
- [ ] Back up the `traefik-acme` volume (holds the ACME account key + certs).

## Ops notes

- **Changing service names?** Always `docker compose down --remove-orphans`
  (I-014/W-006: orphan containers keep their Traefik labels and silently
  steal routes → phantom 404s).
- **A 404 through the proxy has two identical-looking causes** (W-022):
  orphans vs a crash-looping backend. `docker compose ps` FIRST — if a
  service is `Restarting`, go to `docker compose logs <svc>`, not Traefik.
- **Room state** persists across restarts in the `room-state` volume
  (`--state-file /data/room-state.json`); contestants rejoin with their
  stored token.
- **Room ↔ dart_services** talk over the in-cluster `fitd` network
  (`http://dart-services:8300`) — not through the proxy.
- The dev `relay_4501.py` dumb-pipe is **not** used here; Traefik's
  path-based routing replaces it.

## Local verification (no Docker / no TLS / no DNS)

```bash
docker compose -f docker-compose.yml -f deploy/docker-compose.local.yml up -d
# apex (app)    → http://127.0.0.1:8080
# backend (API) → http://127.0.0.1:4503   (room + dart_services only)
# "tailnet"     → http://127.0.0.1:4443   (loopback stands in for the tailnet)
```
The WI-100 split is mirrored with ports: `:8080` serves ONLY the app,
`:4503` ONLY the API — so a locally-built app pointed at
`--dart-define=ROOM_URL=http://<host>:4503`
`--dart-define=DART_SERVICES_URL=http://<host>:4503` exercises the same
cross-origin (CORS) path production does. The structural gate is
identical: `:8080` and `:4501` have no `/admin` or `/api/admin/*` route;
`:4443` does. No `TAILSCALE_IP` / `ACME_EMAIL` needed locally.

# fitd26 generation backend

fitd26 generates Flutter apps from contestants' one-shot prompts by calling a
self-hosted **`dart_services`** (the DartPad backend) over HTTP. The stock
`dart_services` only speaks Gemini; this deployment uses a fork that swaps the
Gemini client for any **OpenAI-compatible** endpoint (Berget AI here).

## Where the backend lives

- **Repo:** [`flutter-and-friends/dart-pad`](https://github.com/flutter-and-friends/dart-pad)
  (fork of [`dart-lang/dart-pad`](https://github.com/dart-lang/dart-pad))
- **Branch:** `berget-backend`
- **The change:** one file —
  [`pkgs/dart_services/lib/src/generative_ai.dart`](https://github.com/flutter-and-friends/dart-pad/blob/berget-backend/pkgs/dart_services/lib/src/generative_ai.dart)
  replaces the Gemini client with a streaming OpenAI-compatible chat client.
  Everything else is untouched upstream, so syncing with `dart-lang/dart-pad`
  stays a trivial rebase of a single-file diff.

The app does **not** depend on the backend as a Dart package — it calls it over
HTTP (`POST /api/v3/generateCode`), so the "git dependency" is this pinned
repo + branch reference plus the run command below.

## Run it

```bash
git clone -b berget-backend https://github.com/flutter-and-friends/dart-pad.git
cd dart-pad/pkgs/dart_services
dart pub get

export BERGET_REFRESH_TOKEN=...        # required — Berget OAuth refresh token
export BERGET_MODEL=google/gemma-4-31B-it   # optional (default shown)
export BERGET_API_URL=https://api.berget.ai # optional (default shown)

dart bin/server.dart --port 8300        # binds 0.0.0.0
```

Config surface: `BERGET_REFRESH_TOKEN` (required), `BERGET_MODEL`,
`BERGET_API_URL`. With no token set, generation is disabled but the rest of the
server (`/api/v3/analyze`, etc.) still works.

## API the app calls

```
POST {base}/api/v3/generateCode
body: {"appType":"dart"|"flutter", "prompt": string, "attachments": []}
→ 200 text/plain; charset=utf-8 — chunked stream of incremental code text
  (the ```dart fence is already stripped server-side; client appends chunks).
→ attachments must be [] (non-empty → 400).
→ errors before streaming: HTTP 4xx/5xx text body; mid-stream failure is a
  silently truncated stream (treat truncation as failure).
```

CORS is permissive (`Access-Control-Allow-Origin: *`) out of the box, so the
web app can call it cross-origin.

## Self-hosted compile + serve (Tier C)

The backend also compiles a contestant's Flutter source to runnable web JS and
serves it chromeless for an iframe — replacing the dartpad.dev embed. The
Flutter-web `project_templates/` and `artifacts/` are built with:

```bash
cd pkgs/dart_services
dart tool/grind.dart                          # artifacts (dart_sdk, flutter_web, ddc loader)
dart tool/grind.dart build-project-templates  # dart_project + flutter_project templates
# then restart so the server picks them up:
svcwatchctl restart fitd26-backend
```

(`artifacts/canvaskit/` is vendored from a `flutter build web` output — the
aarch64 linux download 404s upstream.)

```
POST {base}/api/v3/compileAndServe
body: {"source": "<full dart source>"}
→ 200 {"id", "url": "/compiled/<id>", "jsUrl", "expiresAt"}   (id = content hash, 2 h TTL)
→ 400 {"error": "compile_failed", "problems": ["main.dart:L:C: Error: …", …]}

GET  {base}/compiled/<id>            → chromeless HTML runner (iframe this)
GET  {base}/compiled/<id>/main.dart.js
GET  {base}/artifacts/…              → require.js, flutter.js, ddc loader, dart_sdk_new,
                                       flutter_web_new, canvaskit/ engine bundle

POST {base}/api/v3/suggestFix        → fix loop for compile failures
body: {"appType":"flutter", "errorMessage": "<joined problems[]>", "line":0, "column":0, "source":"…"}
→ 200 text/plain streamed corrected source. Field is `errorMessage`, NOT `message`.
```

Full contract + ops notes: `scratch/fitd26-verification/compile/SERVING.md`;
benchmarks: `scratch/fitd26-verification/compile/RESULTS.md`.

## Pointing the app at it

`apps/fitd26/lib/generation/generation_client.dart` resolves the backend URL:

- `--dart-define=DART_SERVICES_URL=...` always wins;
- otherwise, when the app is opened on loopback it uses `http://127.0.0.1:8300`;
- when opened from another device it targets `<that-host>:4501` (the published
  port for the backend in the dev container).

## Updating from upstream

```bash
git remote add upstream https://github.com/dart-lang/dart-pad.git
git fetch upstream
git rebase upstream/main berget-backend   # single-file diff → usually clean
```

---

# Room-state service (replaces Firebase)

`apps/fitd26/room_service/` is a small Dart shelf service holding the whole
room (challenge, challengers, show state, tri-state reveal) in memory and
driving the per-challenger generate/compile/fix pipeline against the
dart_services fork above. Deliberately a SEPARATE process from dart_services
(different crash/scaling profiles). svcwatch: `fitd26-room` on **8302**,
liveness `GET /api/state`. Optional JSON persistence via `--state-file`.

## Run it

```bash
cd apps/fitd26/room_service
dart pub get
dart bin/server.dart --port 8302 --backend http://127.0.0.1:8300 \
  --state-file /tmp/fitd26-room-state.json
```

## Transport

- **SSE** `GET /api/events` — server→client. Emits a full `state` snapshot on
  every mutation. `id:` = monotonically increasing room `revision`; send
  `Last-Event-ID` to skip a redundant snapshot on reconnect.
- **GET** `/api/state` — the same snapshot as a one-off JSON fetch. Used for
  catch-up refetch on resume (I-054: refetch THEN reopen the stream).
- **POST** — client→server actions below. Permissive CORS.

### State shape (SSE `state` event / GET `/api/state`)

```json
{
  "revision": 93,
  "challenge": { "id", "name", "startTime", "endTime",
                 "widgetUrl": "/compiled/<id>", "assets": {} } | null,
  "challengers": [
    { "id", "name", "joinedAt",
      "status": "active|blocked",
      "prompt": "...",
      "genState": "idle|queued|generating|compiling|ready|failed",
      "generatedCode": "…", "compiledUrl": "/compiled/<id>",
      "error": "…", "fixAttempts": 0 }
  ],
  "show": { "viewMode": "allWithChallenge|allPlayers|singlePlayer|challengeOnly",
            "focusedPlayerId": "…|null" },
  "globalContent": "prompt|code|widget",
  "playerContent": { "<playerId>": "prompt|code|widget" }
}
```

`genState` is the per-challenger pipeline state machine
`queued → generating → compiling → ready | failed`. The buzzer (challenge
`endTime`) blocks editing and queues every prompt for generation immediately
(§6.C step 4). On `failed`, the pipeline auto-runs `suggestFix`→recompile and
falls back to a full regenerate after 2 failed fixes.

## Contestant endpoints

```
POST /api/join            {"name"} → {"playerId","token"}   (token guards prompt writes)
POST /api/prompt          {"playerId","token","prompt"}     → 200 {"ok":true} | 403 | 400
```

The join token is held in the app's localStorage so a reload/background-resume
restores the same identity without re-joining.

## Admin endpoints (NO app-level auth — the Tailscale network gate decides who
## can reach /admin at all; see "Interface split" below)

```
GET  /api/admin/challenges         → 200 {"challenges":[{"name","assets":{},"widgetUrl":"/compiled/<id>"|null}]}
POST /api/admin/challenges/compile {"name"} → 200 {"ok":true,"url":"/compiled/<id>"} | 404 {"error":"unknown challenge"} | 400 {"error":"compile_failed","problems":[...]}
POST /api/admin/challenge        {"name","widgetUrl","startTime","endTime"(ms),"assets"}
POST /api/admin/clear            {}                                  (clear challenge)
POST /api/admin/adjustTime       {"seconds"}                         (± end time)
POST /api/admin/showView         {"viewMode"?, "focusedPlayerId"}    (audience view)
POST /api/admin/contentAll       {"content":"prompt|code|widget"}    (tri-state, ALL)
POST /api/admin/contentFor       {"playerId","content"}              (tri-state, single)
POST /api/admin/regenerate       {"playerId"}                        (manual backstop)
POST /api/admin/removeChallenger {"playerId"}
POST /api/admin/removeAll        {}
```

The tri-state reveal (`contentAll` / `contentFor`) is what the admin flips to
show Prompt | Code | Widget; it applies identically to `/show` AND each
contestant's own done screen. Switching to Code/Widget before `ready` shows a
plasma loader.

## Interface split (the /admin Tailscale gate)

`scratch/fitd26-verification/spa_server.py` serves `build/web` on TWO
listeners over the same SPA root:

- **Public `0.0.0.0:4500`** — serves `/`, `/show`, contestant traffic.
  `/admin` (and under it) → **404**.
- **Admin `127.0.0.1:4502`** in the dev container; the host's **Tailscale IP**
  at the event — serves ONLY `/admin`. Everything else → **404**.

There is no app-level auth on `/admin`: the interface gate IS the auth. At the
event the admin listener binds the tailnet IP instead of loopback, so only
devices on the tailnet (the admin phone) reach it; venue Wi-Fi gets a 404.
Verified here: `/admin` 404 on public (loopback + eth0) and 200 on the
restricted interface; `/` and `/show` 404 on the restricted interface.

> Deployment note: if the event server runs INSIDE a container on the host,
> that container needs tailnet access (Tailscale in it, or the host tailnet
> IP published in) for the admin listener to be bindable there.


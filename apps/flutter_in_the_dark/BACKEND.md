# Flutter in the Dark generation backend

Flutter in the Dark generates Flutter apps from contestants' one-shot prompts by calling a
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
svcwatchctl restart flutter-in-the-dark-backend
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

Full contract + ops notes: `scratch/flutter-in-the-dark-verification/compile/SERVING.md`;
benchmarks: `scratch/flutter-in-the-dark-verification/compile/RESULTS.md`.

## Pointing the app at it

`apps/flutter_in_the_dark/lib/generation/generation_client.dart` resolves the backend URL:

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

`apps/flutter_in_the_dark/room_service/` is a small Dart shelf service holding the whole
room (challenge, challengers, show state, tri-state reveal) in memory and
driving the per-challenger generate/compile/fix pipeline against the
dart_services fork above. Deliberately a SEPARATE process from dart_services
(different crash/scaling profiles). svcwatch: `flutter-in-the-dark-room` on **8302**,
liveness `GET /api/state`. Optional JSON persistence via `--state-file`.

## Run it

```bash
cd apps/flutter_in_the_dark/room_service
dart pub get
dart bin/server.dart --port 8302 --backend http://127.0.0.1:8300 \
  --state-file /tmp/flutter-in-the-dark-room-state.json
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
  "roundId": "<uuid — player-set generation, bumps ONLY on admin removeAll>",
  "challenge": { "id", "name",
                 "startTime", "endTime",   // UTC ISO-8601 with 'Z' suffix —
                                           // DateTime.parse is instant-correct in any zone
                 "widgetUrl": "/compiled/<id>", "assets": {} } | null,
  "challengers": [
    { "id", "name", "joinedAt",
      "status": "active|blocked",
      "prompt": "...",
      "genState": "idle|queued|generating|compiling|ready|failed",
      "generatedCode": "…", "compiledUrl": "/compiled/<id>",
      "error": "…", "fixAttempts": 0 }
  ],
  "show": { "viewMode": "allWithChallenge|allPlayers|singlePlayer|singleWithChallenge|challengeOnly",
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
GET  /api/session?playerId=<id> → 200 {"known":bool, "name":string|null}
POST /api/join            {"name"} → {"playerId","token","roundId"}   (token guards prompt writes)
POST /api/prompt          {"playerId","token","prompt"}     → 200 {"ok":true} | 403 | 400
```

Players PERSIST across challenges: join-and-wait before the first challenge is
supported, and setChallenge / clearChallenge never invalidate a session — a new
challenge only resets each challenger's pipeline fields (genState/status/
generatedCode/compiledUrl/error/fixAttempts), keeping identity and prompt text.

Identity invalidation is admin-initiated ONLY:
- `removeChallenger` kicks one player: their token dies (writes 403) and they
  disappear from the snapshot's `challengers` list.
- `removeAll` kicks everyone: all tokens die, the list empties, and `roundId`
  (the player-set generation) bumps so a client comparing generations notices.

`/api/session` is the server's definitive answer to "here's my ID — do you know
me?": `known:false` (never joined, kicked, or cleared) → the client re-enters a
name; `known:true` carries the server-side display `name`. It is a read — it
never re-registers. The passive equivalent: a stored playerId absent from the
snapshot's `challengers` list means the same thing.

The join token is NOT round-bound: it validates while its playerId is still
registered. Tokens live in memory only, so a service restart invalidates every
session while the challenger rows survive (state file) — a client then sees
`known:true` but its writes 403. Client rule: any 403 on `/api/prompt` means
the session is dead → re-join with a fresh name (there is no token re-issue).

## Admin endpoints (NO app-level auth — the Tailscale network gate decides who
## can reach /admin at all; see "Interface split" below)

```
GET  /api/admin/challenges         → 200 {"challenges":[{"name","assets":{},"widgetUrl":"/compiled/<id>"|null}]}
POST /api/admin/challenges/compile {"name"} → 200 {"ok":true,"url":"/compiled/<id>"} | 404 {"error":"unknown challenge"} | 400 {"error":"compile_failed","problems":[...]}
POST /api/admin/challenge        {"name","widgetUrl","startTime","endTime"(ms since epoch, UTC),"assets"}
POST /api/admin/clear            {}                                  (clear challenge)
POST /api/admin/adjustTime       {"seconds"}                         (± end time)
POST /api/admin/showView         {"viewMode"?, "focusedPlayerId"}    (audience view)
POST /api/admin/contentAll       {"content":"prompt|code|widget"}    (tri-state, ALL)
POST /api/admin/contentFor       {"playerId","content"}              (tri-state, single)
POST /api/admin/regenerate       {"playerId"}                        (manual backstop)
POST /api/admin/removeChallenger {"playerId"}
POST /api/admin/removeAll        {}
```

room_service warms the compiled-challenge cache best-effort: every registry
 entry is compiled in the background at startup, and the picked challenge is
 re-warmed (fire-and-forget) on `POST /api/admin/challenge`. A warm failure is
 logged and skipped, never fatal — the liveness probe + recompile on the
 list/compile routes remains the correctness floor.

### Challenge catalog (authoring)

The picker catalog lives on disk under `apps/flutter_in_the_dark/room_service/challenges/`:

```
challenges/<slug>/source.dart   — full self-contained Flutter app source
challenges/<slug>/assets/*.txt  — text assets (filename minus extension → key)
```

- Every dir containing `source.dart` becomes a picker entry. The entry name
  comes from a `// name: <Display Name>` directive on the FIRST line of
  `source.dart` when present, else the humanized slug (`hello-dark` →
  `Hello Dark`). The directive line is STRIPPED before serving — the compile
  input stays byte-identical to an equivalent seed-authored source.
- Slug rule: lowercase, non-alphanumeric runs → `-` (`'Hello, Dark!'` ↔
  `hello-dark`). Assets load from the entry's OWN directory, even when a
  directive renames it.
- When ANY disk `source.dart` entries exist, they ARE the whole catalog; the
  hardcoded `ChallengeRegistry.seed` in `lib/challenges.dart` is only a
  fallback for an empty/missing challenges dir (kept so a bare checkout still
  boots with 'Hello, Dark!'). A dir with `assets/` but no `source.dart` only
  contributes assets to a matching entry (seed fallback or directive-renamed
  disk entry); otherwise it is ignored.
- Files are read ONCE at startup: adding/editing a challenge requires a
  server restart (same as the historical disk-asset behavior).
- Sources must compile under dart_services' flutter_web template: pure
  `package:flutter/material.dart`, no packages. The `challenges/` dir is
  excluded from `dart analyze` for this reason — the sources are data, not
  package code.
- To preview a challenge live while authoring it (hot reload, same package
  set the compiler provides), use the sibling harness in
  `apps/flutter_in_the_dark/challenge_preview/` — `tool/preview.sh <slug>`. See its
  README.

The tri-state reveal (`contentAll` / `contentFor`) is what the admin flips to
show Prompt | Code | Widget; it applies identically to `/show` AND each
contestant's own done screen. Switching to Code/Widget before `ready` shows a
plasma loader.

## Interface split (the /admin Tailscale gate)

`scratch/flutter-in-the-dark-verification/spa_server.py` serves `build/web` on TWO
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


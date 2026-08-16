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

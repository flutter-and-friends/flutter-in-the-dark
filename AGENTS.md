# Agent setup and Workflow

## Setup commands for asynchronous agents such as Jules

- Setup AI agent machine: `sh setup_agent_machine.sh`

## Rebuild & redeploy

After any change that gets pushed, show the user the exact rebuild/redeploy
steps for the parts that actually changed — don't make them work out which
services are affected. Map the change to the image(s) that bake it, then give
the `docker compose build …` + `docker compose up -d …` commands:

- `apps/flutter_in_the_dark/lib/**` (Flutter client) → **`app`** image (`flutter build web`)
- `apps/flutter_in_the_dark/room_service/**` (Dart shelf backend) → **`room** image
- dart-pad fork (`pkgs/dart_services/**`) → **`dart-services`** image (slow:
  reruns the grind template + artifact builds). Its build context is the
  dart-pad checkout (`DART_PAD_PATH`, default `../dart-pad`), so remind the
  user to pull that checkout too before building.
- `deploy/traefik/**`, `docker-compose.yml` → config only; `docker compose up -d`
  re-reads it, no image rebuild needed.

Untouched services need no rebuild — say so explicitly rather than rebuilding
everything by default.

## Headless browser verification (local stack)

No Docker here, so verify against a local stack: `room_service` on :8302 plus
the release build served statically. Two standing helpers in `/opt/toolbox/bin`
eliminate the recurring time sinks — use them instead of hand-rolling:

```bash
export PATH=/opt/toolbox/bin:$PATH

# 1. Launch headless Chrome CORRECTLY + serve the release build (one command):
fitd-headless-chrome apps/flutter_in_the_dark/build/web 4504
#    Serves build/web on :4504, launches Chrome with the two mandatory flags,
#    prints the CDP endpoint (:9222). --kill stops Chrome.

# 2. STANDING STEP — before testing, confirm the port serves the build you
#    just made (stale http.servers on 4500-4502 serve OLD builds and a new
#    server fails to bind silently):
fitd-verify-served-build apps/flutter_in_the_dark/build/web 4504
```

The two flags `fitd-headless-chrome` sets for you (each is a white-page sink
with a misleading "engine loaded, no error" symptom):

- `--enable-unsafe-swiftshader` — Flutter web renders via WebGL; headless
  forbids the software fallback without it.
- `--lang=en-US` (+`LANG`/`LC_ALL`) — **required**. Without a locale the app
  dies *before* `runApp` with `RangeError: Incorrect locale information
  provided` (empty `navigator.languages`). Looks exactly like the dev-server
  hang but is a different cause.

Gotchas baked into the helpers:

- **Always release build.** `flutter run -d web-server` hangs headless — serve
  `build/web`.
- **`--no-web-resources-cdn` is broken on Flutter 3.44.9**: the build still
  fetches canvaskit from the gstatic CDN (unreachable headless → white page).
  Patch the served `build/web/flutter_bootstrap.js` to inject
  `config: { canvasKitBaseUrl: "canvaskit/" }` into the `_flutter.loader.load({…})`
  call.
- **Driving the UI:** `openchamber_web` works headless here and reads Flutter
  semantics — but it's a single shared localStorage (one player). For multiple
  independent players use a per-tab CDP driver on :9222. Don't click
  `flt-semantics-placeholder` and then run CDP `Runtime.evaluate` — it hangs
  under SwiftShader; read semantics via `openchamber_web` instead.

Frame-timing / perf-measurement traps (burn-reveal investigation, found the
hard way):

- **Path URLs 404 on `http.server`.** With `usePathUrlStrategy`, a real path
  like `/test?burnMode=shader` is a 404 on `python3 -m http.server` (no SPA
  fallback) → you screenshot the default route ("Join the Challenge"), not
  your page. Serve with a 404→`index.html` fallback for any route test.
- **`bool.fromEnvironment` folds to FALSE in dart2js 3.47.** Even with
  `--dart-define=BURN_TIMING=1`, `const bool.fromEnvironment('BURN_TIMING')`
  compiles to `false` and the guarded code is tree-shaken out. `String.fromEnvironment`
  works. Gate diagnostics on the string value, and verify the marker string is
  actually in `main.dart.js` before trusting a run (`grep -c BURN_TIMING_INSTALLED`).
- **Headless SwiftShader hangs CDP `Runtime.evaluate`** (and `consoleAPICalled`
  delivery can stall) — never `evaluate` to read state. Collect timings by
  having the app `console.log` a tagged line and listening to
  `Runtime.consoleAPICalled`, or use `Page.captureScreenshot` (both low-level,
  non-hanging).
- **Stale service worker.** Chrome's persistent profile (the helper passes no
  `--user-data-dir`) can serve a cached OLD app. For a clean run use a fresh
  `--user-data-dir` and confirm the served `serviceWorkerVersion` matches the
  build on disk (`fitd-verify-served-build`).

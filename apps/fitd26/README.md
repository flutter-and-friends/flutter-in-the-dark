# fitd26 — "Prompting in the Dark"

The official application for the Flutter in the Dark 2026 event. This year
contestants don't write code — each writes a **single one-shot prompt**
describing the challenge app. A self-hosted generation backend turns that
prompt into a Flutter app, which runs in a DartPad embed. The audience `/show`
screen watches every player's prompt evolve **live**, in host-switchable
layouts.

## Components

### Contestant view (`/`)
Join (anonymous), write a one-shot prompt in a dark writing surface, and hit
**Generate**. The generated Flutter code streams in and runs in a DartPad
embed. The prompt syncs to Firestore (debounced) as you type.

### Audience view (`/show`)
Watches every player's prompt live, in four host-switchable modes:
all players + challenge · all players · single player · challenge only.

### Admin view (`/admin`)
Manage challengers, set the challenge window, and switch the `/show` view
mode + focused player (Google sign-in required).

## Backend

Two backends:

*   **Firebase** (Cloud Firestore + Auth) — challenge state, challenger
    prompts, host view state. Same project as fitd25.
*   **Generation** — a self-hosted `dart_services` fork
    ([`flutter-and-friends/dart-pad`](https://github.com/flutter-and-friends/dart-pad),
    branch `berget-backend`) that turns prompts into Flutter code via an
    OpenAI-compatible model. **See [BACKEND.md](BACKEND.md) for setup and the
    API contract.** Without it the app runs but Generate has nothing to call.

## Getting Started

Follow the monorepo setup in the root [README.md](../README.md), then:

```bash
cd apps/fitd26
flutter run -d web-server            # dev
flutter build web --release --no-tree-shake-icons   # release bundle
```

For the full loop, also run the generation backend (see BACKEND.md) and point
the app at it with `--dart-define=DART_SERVICES_URL=...` (defaults: loopback →
`http://127.0.0.1:8300`, other devices → `<host>:4501`).

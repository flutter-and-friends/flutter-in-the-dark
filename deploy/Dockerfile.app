# fitd26 SPA — release build, served by nginx with SPA fallback.
#
# Build context: the flutter-in-the-dark REPO ROOT (see docker-compose.yml).
#
#   docker build -f deploy/Dockerfile.app -t fitd26-app:local .
#
# WI-100 host split: the app SPA is served from the APEX
# https://flutterinthedark.dev while the API stays on
# https://backend.flutterinthedark.dev — DIFFERENT origins. ROOM_URL /
# DART_SERVICES_URL are therefore baked to the backend host explicitly
# (same-origin resolution would hit the apex, which has no API routers).
# Both backends answer CORS for the apex origin (room: shelf middleware;
# dart_services: ACAO * — and no X-Frame-Options, so the /compiled/*
# iframes embed cross-origin).
#
# The TAILNET alias still works with this same image: RoomClient resolves
# same-origin when the page's hostname is on the tailnet (*.ts.net) —
# the :4443 proxy fronts app + full API (incl. /api/admin/*) on ONE origin,
# so the admin phone MUST use the https://<machine>.<tailnet>.ts.net:4443
# URL (it already does). Everywhere else the baked backend URL wins.
#
# (An EMPTY dart-define does NOT work as a "fall back" value:
# String.fromEnvironment can't distinguish empty from unset, and the app
# checks isNotEmpty — so the loopback fallback would fire.)

FROM ghcr.io/cirruslabs/flutter:3.47.0 AS build
WORKDIR /src

# Melos workspace: root pubspec + the app. Resolve at the root so the
# workspace overrides apply, then build the app.
COPY pubspec.yaml pubspec.lock melos.yaml ./
COPY apps/fitd26 apps/fitd26
WORKDIR /src/apps/fitd26
RUN flutter pub get

# --no-tree-shake-icons: the app renders json_dynamic_widget-style dynamic
# icon references (W-156 class of bug: tree-shaken icons white-screen the
# release build while dev looks fine).
RUN flutter build web --release --no-tree-shake-icons \
      --dart-define=ROOM_URL=https://backend.flutterinthedark.dev \
      --dart-define=DART_SERVICES_URL=https://backend.flutterinthedark.dev

FROM nginx:1.27-alpine
COPY deploy/nginx-app.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/apps/fitd26/build/web /usr/share/nginx/html
EXPOSE 80

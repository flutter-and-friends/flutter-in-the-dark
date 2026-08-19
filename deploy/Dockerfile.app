# fitd26 SPA — release build, served by nginx with SPA fallback.
#
# Build context: the flutter-in-the-dark REPO ROOT (see docker-compose.yml).
#
#   docker build -f deploy/Dockerfile.app -t fitd26-app:local .
#
# ROOM_URL / DART_SERVICES_URL are built as the `same-origin` SENTINEL: the
# app then resolves both backends to web.window.location.origin — i.e. it
# calls the API on whatever host:port served it (the proxy). One build thus
# serves the public domain, the Tailscale alias, and local verification
# unchanged. (An EMPTY dart-define does NOT work: String.fromEnvironment
# can't distinguish empty from unset, and the app checks isNotEmpty — so the
# loopback fallback would fire. The sentinel is what makes same-origin win.)

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
      --dart-define=ROOM_URL=same-origin \
      --dart-define=DART_SERVICES_URL=same-origin

FROM nginx:1.27-alpine
COPY deploy/nginx-app.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/apps/fitd26/build/web /usr/share/nginx/html
EXPOSE 80

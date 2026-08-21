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

# Flutter SDK from source (NOT a prebuilt image). ghcr.io/cirruslabs/flutter
# lags Flutter releases — it had no 3.47.0 tag (only up to 3.44.0) when the
# app needed 3.47.0, breaking the build with "not found". Mirror the proven
# pattern in Dockerfile.dart-services: amd64 uses the checksum-pinned official
# tarball; arm64 has no upstream tarball so we clone the stable tag.
FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.47.0
ARG FLUTTER_SHA256=26cd99d3d94b1367e6b50535a18aeef0282c10a535bbe3ec493534dcdab75296
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl xz-utils ca-certificates git unzip \
    && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in \
      amd64) \
        curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
        && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
        && tar -xJf /tmp/flutter.tar.xz -C /opt \
        && rm /tmp/flutter.tar.xz ;; \
      arm64) \
        git clone --depth 1 --branch "${FLUTTER_VERSION}" \
          https://github.com/flutter/flutter.git /opt/flutter ;; \
      *) echo "unsupported TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
    esac \
 && git config --global --add safe.directory /opt/flutter \
 && /opt/flutter/bin/flutter --version \
 && /opt/flutter/bin/flutter precache --web
ENV PATH="/opt/flutter/bin:${PATH}"
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

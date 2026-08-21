# Agent setup and Workflow

## Setup commands for asynchronous agents such as Jules

- Setup AI agent machine: `sh setup_agent_machine.sh`

## Rebuild & redeploy

After any change that gets pushed, show the user the exact rebuild/redeploy
steps for the parts that actually changed — don't make them work out which
services are affected. Map the change to the image(s) that bake it, then give
the `docker compose build …` + `docker compose up -d …` commands:

- `apps/fitd26/lib/**` (Flutter client) → **`app`** image (`flutter build web`)
- `apps/fitd26/room_service/**` (Dart shelf backend) → **`room** image
- dart-pad fork (`pkgs/dart_services/**`) → **`dart-services`** image (slow:
  reruns the grind template + artifact builds). Its build context is the
  dart-pad checkout (`DART_PAD_PATH`, default `../dart-pad`), so remind the
  user to pull that checkout too before building.
- `deploy/traefik/**`, `docker-compose.yml` → config only; `docker compose up -d`
  re-reads it, no image rebuild needed.

Untouched services need no rebuild — say so explicitly rather than rebuilding
everything by default.

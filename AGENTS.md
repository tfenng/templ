# Repository Guidelines

## Project Structure & Module Organization

This repository contains reusable deployment templates, not application source code. The root `README.md` describes the shared model: centralized project variables plus Docker Compose orchestration.

- `java/` is the implemented template for a Spring Boot fat-jar backend, static frontend assets, MySQL, Redis, and nginx.
- `java/docker-compose.yml` defines the runtime services.
- `java/bin/update.sh` builds and deploys the backend from `${SRC_BACKEND}`.
- `java/bin/update-web.sh` builds and deploys frontend assets from `${SRC_FRONTEND}`.
- `java/nginx/conf/nginx.conf` contains reverse proxy configuration.
- `python/` and `golang/` are placeholders documenting required differences from `java/`.

## Build, Test, and Development Commands

Run commands from the relevant template directory, usually `java/`.

```bash
docker compose config
```

Validates `.env` expansion, service definitions, mounts, and ports.

```bash
docker compose up -d
docker compose ps
```

Starts the stack and checks service health.

```bash
bin/update.sh
bin/update-web.sh
```

Pull external backend/frontend repositories, build artifacts, sync outputs, and restart or refresh the relevant service.

```bash
bash -n java/bin/update.sh java/bin/update-web.sh
```

Checks shell script syntax after edits.

## Coding Style & Naming Conventions

Keep templates variable-driven. Project-specific names, paths, ports, credentials, and artifact names should live in `.env`; Compose files and scripts should derive from those variables. Shell scripts use `#!/bin/bash`, `set -euo pipefail`, uppercase environment variables, and concise status output. Preserve the service names `mysql`, `redis`, `app`, and `web` unless a structural change requires otherwise.

## Testing Guidelines

There is no unit test suite in this repository. Validate changes by running `docker compose config` for affected templates and `bash -n` for edited shell scripts. For nginx changes, include a config validation step in the target environment, such as `docker compose exec web nginx -t`, when the stack is running.

## Commit & Pull Request Guidelines

Git history is not available in this working copy, so use clear, imperative commit messages that name the affected template, for example `java: tighten app health configuration` or `docs: clarify Python template TODOs`. Pull requests should explain the deployment behavior changed, list validation commands run, and call out required `.env` migrations. Include screenshots only when web-facing nginx behavior or rendered static assets are affected.

## Security & Configuration Tips

Do not commit real production secrets. Treat `.env` values as examples unless explicitly intended for a private deployment repository. Change `DATABASE_PASSWORD` and exposed ports before production use, and keep generated logs such as `java/nginx/log/access.log` out of unrelated documentation or template edits.

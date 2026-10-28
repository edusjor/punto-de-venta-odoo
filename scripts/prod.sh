#!/usr/bin/env bash
# Atajo para docker compose con la configuración de producción.
#   ./scripts/prod.sh up -d
#   ./scripts/prod.sh ps
#   ./scripts/prod.sh logs -f odoo
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker compose -f docker-compose.yml -f docker-compose.prod.yml "$@"

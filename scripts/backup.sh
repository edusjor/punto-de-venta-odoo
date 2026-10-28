#!/usr/bin/env bash
# Respalda una base de Odoo (dump de PostgreSQL + filestore) en backups/ y
# borra los respaldos con más de KEEP_DAYS días. Pensado para cron en el VPS.
#
#   ./scripts/backup.sh                 # base ODOO_DB de .env (o odoo_pos)
#   ./scripts/backup.sh odoo_otra
#   KEEP_DAYS=30 ./scripts/backup.sh
#
# Genera backups/<base>_<fecha>.dump y backups/<base>_<fecha>_filestore.tgz
# (mismo formato que backup.ps1; se restauran con restore.sh o restore.ps1).
set -euo pipefail
cd "$(dirname "$0")/.."

DB="${1:-$(grep -E '^ODOO_DB=' .env 2>/dev/null | cut -d= -f2 || true)}"
DB="${DB:-odoo_pos}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date +%Y%m%d_%H%M%S)"
DUMP="${DB}_${STAMP}.dump"
FS="${DB}_${STAMP}_filestore.tgz"

mkdir -p backups
echo "[$(date '+%F %T')] Respaldando base $DB ..."
docker compose exec -T db sh -c "pg_dump -U \"\$POSTGRES_USER\" -Fc -d '$DB' -f /tmp/$DUMP"
docker compose cp "db:/tmp/$DUMP" "backups/$DUMP" >/dev/null
docker compose exec -T db rm -f "/tmp/$DUMP"

echo "[$(date '+%F %T')] Respaldando filestore ..."
# Se empaqueta en /tmp del contenedor y se copia con docker: no depende de los
# permisos de backups/ en el host (el contenedor corre como usuario odoo).
if docker compose exec -T odoo sh -c "test -d /var/lib/odoo/filestore/$DB"; then
    docker compose exec -T odoo tar -czf "/tmp/$FS" -C /var/lib/odoo/filestore "$DB"
    docker compose cp "odoo:/tmp/$FS" "backups/$FS" >/dev/null
    docker compose exec -T odoo rm -f "/tmp/$FS"
else
    echo "Sin filestore para $DB"
fi

# Rotación: solo respaldos de esta base con más de KEEP_DAYS días
find backups -maxdepth 1 -type f \( -name "${DB}_*.dump" -o -name "${DB}_*_filestore.tgz" \) \
    -mtime +"$KEEP_DAYS" -print -delete | sed 's/^/Borrado (antiguo): /'

echo "[$(date '+%F %T')] Listo:"
ls -lh "backups/$DUMP" "backups/$FS" 2>/dev/null || ls -lh "backups/$DUMP"

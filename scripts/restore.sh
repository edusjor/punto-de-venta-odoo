#!/usr/bin/env bash
# Restaura un respaldo (backup.sh / backup.ps1) en una base NUEVA.
# No sobrescribe bases existentes: si el nombre ya existe, se detiene.
#
#   ./scripts/restore.sh backups/odoo_pos_20261028_115744.dump odoo_pos
#
# El filestore se busca como <mismo nombre>_filestore.tgz dentro de backups/.
set -euo pipefail
cd "$(dirname "$0")/.."

DUMP="${1:?Uso: restore.sh <archivo.dump> <base_nueva>}"
DB="${2:?Uso: restore.sh <archivo.dump> <base_nueva>}"

[[ "$DB" =~ ^odoo_[a-z0-9_]+$ ]] || { echo "El nombre debe empezar por odoo_ y usar solo a-z, 0-9, _"; exit 1; }
[[ -f "$DUMP" ]] || { echo "No existe $DUMP"; exit 1; }

if docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d postgres -tAl' | cut -d'|' -f1 | grep -qx "$DB"; then
    echo "La base $DB ya existe. Elija otro nombre (no se sobrescriben datos)."
    exit 1
fi

NAME="$(basename "$DUMP")"
echo "Restaurando $NAME en $DB ..."
docker compose cp "$DUMP" "db:/tmp/$NAME" >/dev/null
docker compose exec -T db sh -c \
    "createdb -U \"\$POSTGRES_USER\" -O \"\$POSTGRES_USER\" '$DB' && pg_restore -U \"\$POSTGRES_USER\" -d '$DB' --no-owner --role=\"\$POSTGRES_USER\" /tmp/$NAME"
docker compose exec -T db rm -f "/tmp/$NAME"

FS="${DUMP%.dump}_filestore.tgz"
if [[ -f "$FS" ]]; then
    FSNAME="$(basename "$FS")"
    SRC_DB="$(echo "$NAME" | sed -E 's/_[0-9]{8}_[0-9]{6}\.dump$//')"
    echo "Restaurando filestore $FSNAME ..."
    # Se copia con docker (no depende de permisos de backups/ en el host); el
    # filestore se extrae con el nombre original y se renombra al nuevo.
    docker compose cp "$FS" "odoo:/tmp/$FSNAME" >/dev/null
    docker compose exec -T odoo sh -c \
        "mkdir -p /tmp/fsr /var/lib/odoo/filestore && tar -xzf /tmp/$FSNAME -C /tmp/fsr && mv /tmp/fsr/$SRC_DB /var/lib/odoo/filestore/$DB && rm -rf /tmp/fsr"
    docker compose exec -T -u root odoo rm -f "/tmp/$FSNAME"
else
    echo "AVISO: no se encontró $FS; se restauró solo la base de datos."
fi

echo "Restaurado: $DB"

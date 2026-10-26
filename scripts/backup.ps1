<#
.SYNOPSIS
  Respalda una base de datos de Odoo (dump de PostgreSQL + filestore).

.EXAMPLE
  .\scripts\backup.ps1                       # respalda odoo_restaurante_dev
  .\scripts\backup.ps1 -Database odoo_otra

  Genera en backups\:
    <db>_<fecha>.dump            (pg_dump formato custom)
    <db>_<fecha>_filestore.tgz   (adjuntos e imágenes)
#>
param(
    [string]$Database = "odoo_restaurante_dev"
)
# Continue: docker escribe progreso en stderr; los errores se detectan con $LASTEXITCODE
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dump = "${Database}_${stamp}.dump"
$fs = "${Database}_${stamp}_filestore.tgz"

Write-Host "Respaldando base $Database ..."
docker compose exec -T db sh -c "pg_dump -U `$POSTGRES_USER -Fc -d '$Database' -f /tmp/$dump"
if ($LASTEXITCODE -ne 0) { throw "pg_dump falló" }
docker compose cp "db:/tmp/$dump" "backups/$dump"
docker compose exec -T db rm -f "/tmp/$dump"

Write-Host "Respaldando filestore ..."
docker compose exec -T odoo sh -c "test -d /var/lib/odoo/filestore/$Database && tar -czf /backups/$fs -C /var/lib/odoo/filestore $Database || echo 'Sin filestore para $Database'"
if ($LASTEXITCODE -ne 0) { throw "Respaldo del filestore falló" }

Write-Host "Listo:"
Get-ChildItem backups -Filter "${Database}_${stamp}*" | Format-Table Name, Length

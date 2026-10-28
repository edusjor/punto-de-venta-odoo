<#
.SYNOPSIS
  Restaura un respaldo hecho con backup.ps1 en una base NUEVA.
  No sobrescribe bases existentes: si el nombre ya existe, se detiene.

.EXAMPLE
  .\scripts\restore.ps1 -Dump backups\odoo_pos_20261028_170022.dump -Database odoo_pos_restaurada
  (el filestore se busca automáticamente como <mismo nombre>_filestore.tgz)
#>
param(
    [Parameter(Mandatory = $true)][string]$Dump,
    [Parameter(Mandatory = $true)][string]$Database
)
# Continue: docker escribe progreso en stderr; los errores se detectan con $LASTEXITCODE
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($Database -notmatch '^odoo_[a-z0-9_]+$') { throw "El nombre debe empezar por odoo_ (dbfilter) y usar solo a-z, 0-9, _" }
if (-not (Test-Path $Dump)) { throw "No existe $Dump" }

$dbs = docker compose exec -T db sh -c 'psql -U $POSTGRES_USER -d postgres -tAl' | ForEach-Object { ($_ -split '\|')[0] }
if ($LASTEXITCODE -ne 0) { throw "No se pudo consultar PostgreSQL" }
if ($dbs -contains $Database) { throw "La base $Database ya existe. Elija otro nombre (no se sobrescriben datos)." }

$dumpName = Split-Path -Leaf $Dump
Write-Host "Restaurando $dumpName en $Database ..."
docker compose cp $Dump "db:/tmp/$dumpName"
docker compose exec -T db sh -c "createdb -U `$POSTGRES_USER -O `$POSTGRES_USER '$Database' && pg_restore -U `$POSTGRES_USER -d '$Database' --no-owner --role=`$POSTGRES_USER /tmp/$dumpName"
if ($LASTEXITCODE -ne 0) { throw "pg_restore falló" }
docker compose exec -T db rm -f "/tmp/$dumpName"

$fs = $Dump -replace '\.dump$', '_filestore.tgz'
if (Test-Path $fs) {
    $fsName = Split-Path -Leaf $fs
    $srcDb = $dumpName -replace '_\d{8}_\d{6}\.dump$', ''
    Write-Host "Restaurando filestore $fsName ..."
    # El filestore se extrae con el nombre original y se renombra al nuevo
    docker compose exec -T odoo sh -c "mkdir -p /tmp/fsr && tar -xzf /backups/$fsName -C /tmp/fsr && mkdir -p /var/lib/odoo/filestore && mv /tmp/fsr/$srcDb /var/lib/odoo/filestore/$Database && rm -rf /tmp/fsr"
    if ($LASTEXITCODE -ne 0) { throw "Restauración del filestore falló (el .tgz debe estar dentro de backups\)" }
} else {
    Write-Warning "No se encontró $fs; se restauró solo la base de datos."
}

Write-Host "Restaurado. Abra http://localhost:8069/web?db=$Database"

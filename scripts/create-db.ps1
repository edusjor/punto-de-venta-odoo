<#
.SYNOPSIS
  Crea una base de datos de Odoo con idioma español, país Costa Rica y
  administrador local. La moneda (CRC) y la zona horaria se fijan después
  con configure-db.py.

.EXAMPLE
  .\scripts\create-db.ps1
  .\scripts\create-db.ps1 -Database odoo_pruebas -Demo
#>
param(
    [string]$Database = "odoo_pos",
    [string]$Lang = "es_419",
    [string]$Country = "cr",
    [switch]$Demo
)
# Continue: docker escribe progreso en stderr; los errores se detectan con $LASTEXITCODE
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Lee .env sin exponer valores en pantalla
$envVars = @{}
Get-Content .env | Where-Object { $_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$' } | ForEach-Object {
    $envVars[$Matches[1]] = $Matches[2].Trim()
}
foreach ($k in "ODOO_ADMIN_LOGIN", "ODOO_ADMIN_PASSWORD") {
    if (-not $envVars[$k]) { throw "Falta $k en .env" }
}
$port = if ($envVars["ODOO_HTTP_PORT"]) { $envVars["ODOO_HTTP_PORT"] } else { "8069" }

# Línea de comandos de Odoo ("odoo db init"): funciona con list_db = False,
# que deja deshabilitado el gestor de bases por web.
$demoArg = if ($Demo) { "--with-demo" } else { "" }
Write-Host "Creando $Database (idioma $Lang, país $Country, demo=$([bool]$Demo)). Puede tardar 1-3 minutos..."
docker compose exec -T -e "NEW_ADMIN_LOGIN=$($envVars['ODOO_ADMIN_LOGIN'])" -e "NEW_ADMIN_PASSWORD=$($envVars['ODOO_ADMIN_PASSWORD'])" odoo `
    sh -c "odoo db init '$Database' --language $Lang --country $Country $demoArg --username `"`$NEW_ADMIN_LOGIN`" --password `"`$NEW_ADMIN_PASSWORD`""
if ($LASTEXITCODE -ne 0) { throw "odoo db init falló" }

Write-Host "Instalando módulos propios (login simplificado)..."
docker compose exec -T odoo odoo -d $Database -i restaurante_login --stop-after-init --no-http --log-level=warn
if ($LASTEXITCODE -ne 0) { throw "Instalación de restaurante_login falló" }

Write-Host "Aplicando moneda CRC y zona horaria America/Costa_Rica..."
docker compose cp scripts\configure-db.py odoo:/tmp/configure-db.py
docker compose exec -T odoo sh -c "odoo shell -d '$Database' --no-http --log-level=warn < /tmp/configure-db.py"
if ($LASTEXITCODE -ne 0) { throw "configure-db.py falló" }

Write-Host "Base creada: http://localhost:$port/web?db=$Database  (usuario: $($envVars['ODOO_ADMIN_LOGIN']))"

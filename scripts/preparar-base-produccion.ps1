<#
.SYNOPSIS
  Construye en local la base limpia de producción y la respalda en backups\,
  lista para restaurar en el VPS (ver DEPLOY.md).

  Contenido: compañía The Club House (logo, Costa Rica, CRC), módulos de PdV,
  restaurante y empleados con PIN, login simplificado, los productos del Excel,
  las compañías adicionales (sin productos) y un único usuario administrador
  (ODOO_ADMIN_LOGIN de .env.production) con acceso a todas.

.EXAMPLE
  .\scripts\preparar-base-produccion.ps1
  .\scripts\preparar-base-produccion.ps1 -Logo C:\ruta\logo.b64 -ExtraCompanies "Barra Brava Yoses"
#>
param(
    [string]$EnvFile = ".env.production",
    [string]$Excel = "PRODCUTOS TCH.xlsx",
    [string]$Logo = "",
    [string[]]$ExtraCompanies = @("Barra Brava Yoses")
)
# Continue: docker escribe progreso en stderr; los errores se detectan con $LASTEXITCODE
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$prod = @{}
Get-Content $EnvFile | Where-Object { $_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$' } | ForEach-Object {
    $prod[$Matches[1]] = $Matches[2].Trim()
}
foreach ($k in "ODOO_DB", "ODOO_ADMIN_LOGIN", "ODOO_ADMIN_PASSWORD", "ODOO_ADMIN_PIN", "ODOO_DOMAIN") {
    if (-not $prod[$k]) { throw "Falta $k en $EnvFile" }
}
$db = $prod["ODOO_DB"]

$dbs = docker compose exec -T db sh -c 'psql -U $POSTGRES_USER -d postgres -tAl' | ForEach-Object { ($_ -split '\|')[0] }
if ($dbs -contains $db) { throw "La base $db ya existe en local. Bórrela primero si quiere regenerarla." }

Write-Host "1/6 Creando $db ..."
docker compose exec -T -e "NEW_ADMIN_LOGIN=$($prod['ODOO_ADMIN_LOGIN'])" -e "NEW_ADMIN_PASSWORD=$($prod['ODOO_ADMIN_PASSWORD'])" odoo `
    sh -c "odoo db init '$db' --language es_419 --country cr --username `"`$NEW_ADMIN_LOGIN`" --password `"`$NEW_ADMIN_PASSWORD`" > /tmp/dbinit.log 2>&1"
if ($LASTEXITCODE -ne 0) { throw "odoo db init falló (ver /tmp/dbinit.log en el contenedor)" }

Write-Host "2/6 Instalando módulos ..."
docker compose exec -T odoo odoo -d $db -i point_of_sale,pos_restaurant,pos_hr,restaurante_login --stop-after-init --no-http --log-level=warn
if ($LASTEXITCODE -ne 0) { throw "Instalación de módulos falló" }

Write-Host "3/6 Compañía, moneda y zona horaria ..."
docker compose cp scripts\configure-db.py odoo:/tmp/configure-db.py 2>&1 | Out-Null
docker compose exec -T odoo sh -c "odoo shell -d '$db' --no-http --log-level=warn < /tmp/configure-db.py"
if ($LASTEXITCODE -ne 0) { throw "configure-db.py falló" }

Write-Host "4/6 Productos ($Excel) ..."
docker compose cp $Excel odoo:/tmp/productos.xlsx 2>&1 | Out-Null
docker compose cp scripts\import-productos.py odoo:/tmp/import-productos.py 2>&1 | Out-Null
docker compose exec -T odoo sh -c "odoo shell -d '$db' --no-http --log-level=warn < /tmp/import-productos.py"
if ($LASTEXITCODE -ne 0) { throw "import-productos.py falló" }

Write-Host "5/6 Administrador único, PIN, logo y URL pública ..."
docker compose exec -T -u root odoo rm -f /tmp/company_logo.b64
if ($Logo) { docker compose cp $Logo odoo:/tmp/company_logo.b64 2>&1 | Out-Null }
docker compose cp scripts\setup-admin-produccion.py odoo:/tmp/setup-admin-produccion.py 2>&1 | Out-Null
docker compose exec -T -e "ADMIN_PIN=$($prod['ODOO_ADMIN_PIN'])" -e "BASE_URL=https://$($prod['ODOO_DOMAIN'])" odoo `
    sh -c "odoo shell -d '$db' --no-http --log-level=warn < /tmp/setup-admin-produccion.py"
if ($LASTEXITCODE -ne 0) { throw "setup-admin-produccion.py falló" }

docker compose cp scripts\crear-compania.py odoo:/tmp/crear-compania.py 2>&1 | Out-Null
foreach ($company in $ExtraCompanies) {
    Write-Host "    Compañía adicional: $company ..."
    docker compose exec -T -e "COMPANY_NAME=$company" -e "ADMIN_PIN=$($prod['ODOO_ADMIN_PIN'])" odoo `
        sh -c "odoo shell -d '$db' --no-http --log-level=warn < /tmp/crear-compania.py"
    if ($LASTEXITCODE -ne 0) { throw "crear-compania.py falló para $company" }
}

Write-Host "6/6 Respaldo para el VPS ..."
.\scripts\backup.ps1 -Database $db

# Despliegue en VPS — `pos.loshinchassportbar.com`

Guía paso a paso para poner en producción Odoo 19 Community (POS de restaurantes) en un VPS
**nuevo** con Ubuntu 24.04. Todo lo necesario ya está preparado en este directorio.

## Qué se despliega

| Elemento | Detalle |
|---|---|
| Base de datos | `odoo_pos`: compañías **The Club House** (logo, 41 productos, IVA 13 % incluido) y **Barra Brava Yoses** (sin productos). Costa Rica, CRC, `es_419` |
| Módulos | Punto de venta, Restaurante (mesas), Empleados con PIN (`pos_hr`), `restaurante_login` (login simplificado), `l10n_cr`. `pos_comanda_navegador` (comandas por el navegador) **no** está en el respaldo: ver "Instalar un módulo nuevo" |
| Usuarios | `soporte@cam360cr.com` (administrador total de ambas compañías, con PIN de PdV) y `clubhouse` (cuenta de las tablets de The Club House: Punto de venta / Usuario, sin empleado) |
| Punto de venta | Caja **The Club House** con inicio de sesión por empleado: Soporte en *Permisos avanzados*; Mesero1 y Mesero2 (empleados con PIN, sin usuario) |
| Sin datos | Sin pedidos ni clientes. Barra Brava Yoses sin caja ni empleados |
| Servicios | `db` (PostgreSQL 17, sin puerto público), `odoo` (19.0, solo `127.0.0.1:8069`), `caddy` (HTTPS automático en 80/443) |

## Archivos que intervienen

| Archivo (local) | Destino en el VPS | Notas |
|---|---|---|
| Todo el directorio, **excepto** `.git/`, `backups/*`, `.env*`, `assets/` | `/opt/odoo-restaurant/` | Código, configuración y scripts |
| `.env.production` | `/opt/odoo-restaurant/.env` | **Secretos de producción.** No está en Git. No copiar el `.env` local (es de desarrollo) |
| `backups/odoo_pos_20261028_170022.dump` | `/opt/odoo-restaurant/backups/` | Base de producción |
| `backups/odoo_pos_20261028_170022_filestore.tgz` | `/opt/odoo-restaurant/backups/` | Logo y adjuntos |

Credenciales: las técnicas y las de `soporte` están en `.env.production` (`ODOO_ADMIN_LOGIN`,
`ODOO_ADMIN_PASSWORD`, `ODOO_ADMIN_PIN`, `POSTGRES_PASSWORD`, `ODOO_MASTER_PASSWORD`). La contraseña
de `clubhouse` y los PIN de los meseros van dentro de la base (se configuraron en local). No se
escriben en esta guía.

## 0. Requisitos previos

- VPS Ubuntu 24.04, mínimo **2 vCPU y 4 GB de RAM**, puertos 80 y 443 libres.
- DNS: registro **A** `pos.loshinchassportbar.com` → IP del VPS. Verificar antes de seguir:

  ```bash
  dig +short pos.loshinchassportbar.com   # debe devolver la IP del VPS
  ```

  Sin esto Caddy no puede obtener el certificado HTTPS.

## 1. Preparar el VPS (como root)

```bash
apt-get update && apt-get -y upgrade
curl -fsSL https://get.docker.com | sh          # Docker Engine + Compose (repositorio oficial)
docker --version && docker compose version

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

mkdir -p /opt/odoo-restaurant/backups
```

Docker publica puertos por fuera de `ufw`; aquí solo se publican 80/443 (Caddy). Odoo queda en
`127.0.0.1:8069` y PostgreSQL no se publica.

## 2. Copiar los archivos (desde el equipo local, Git Bash)

```bash
cd /c/Users/sopor/Documents/GitHub/punto-de-venta/odoo-restaurant
VPS=root@IP_DEL_VPS        # o el alias SSH configurado

tar --exclude=.git --exclude='./backups/*' --exclude='./.env*' --exclude=./assets \
    --exclude=__pycache__ -czf - . | ssh "$VPS" 'tar -xzf - -C /opt/odoo-restaurant'

scp .env.production "$VPS":/opt/odoo-restaurant/.env
scp backups/odoo_pos_20261028_170022.dump backups/odoo_pos_20261028_170022_filestore.tgz \
    "$VPS":/opt/odoo-restaurant/backups/

ssh "$VPS" 'chmod 600 /opt/odoo-restaurant/.env && chmod +x /opt/odoo-restaurant/scripts/*.sh'
```

## 3. Levantar base de datos y Odoo

```bash
cd /opt/odoo-restaurant
./scripts/prod.sh config --quiet && echo OK     # valida la configuración
./scripts/prod.sh pull
./scripts/prod.sh up -d db odoo
./scripts/prod.sh ps                            # esperar db y odoo "healthy" (~1 min)
```

## 4. Restaurar la base de producción

```bash
./scripts/restore.sh backups/odoo_pos_20261028_170022.dump odoo_pos
./scripts/prod.sh restart odoo
```

El nombre debe ser exactamente `odoo_pos` (`dbfilter = ^odoo_pos$` en `config/odoo.prod.conf`).

## 5. Activar HTTPS

```bash
./scripts/prod.sh up -d                         # arranca caddy
./scripts/prod.sh logs -f caddy                 # esperar "certificate obtained successfully"; Ctrl+C
```

## 6. Verificar

```bash
curl -sI https://pos.loshinchassportbar.com/web/login | head -1     # HTTP/2 200
curl -s  https://pos.loshinchassportbar.com/web/health              # {"status": "pass"}
./scripts/prod.sh logs --since=10m odoo | grep -E " (ERROR|CRITICAL) " || echo "sin errores"
```

En el navegador:

1. `https://pos.loshinchassportbar.com` muestra el login de The Club House (sin "Gestionar bases
   de datos" ni "Con la tecnología de Odoo").
2. Entrar con `ODOO_ADMIN_LOGIN` / `ODOO_ADMIN_PASSWORD`.
3. Arriba a la derecha aparecen las compañías The Club House y Barra Brava Yoses.
4. Punto de venta: aparece la caja The Club House; al abrirla pide elegir empleado y PIN.

## 7. Respaldos automáticos

```bash
crontab -e
# Diario a las 03:00, conserva 14 días:
0 3 * * * cd /opt/odoo-restaurant && ./scripts/backup.sh >> backups/backup.log 2>&1
```

Probarlo una vez a mano: `./scripts/backup.sh`. Recomendado: copiar `backups/` fuera del VPS
(otro servidor, almacenamiento en la nube) con regularidad.

Restaurar en una base nueva: `./scripts/restore.sh backups/<archivo>.dump odoo_pos_copia`.

## 8. Después del despliegue (pendiente)

- **Correo saliente** (para "Restablecer contraseña"): Ajustes → Técnico → Servidores de correo
  saliente, con los datos SMTP de la cuenta que enviará los correos. Se guarda en la base, no en
  archivos.
- **Cambiar la contraseña de `clubhouse` y los PIN de Mesero1 y Mesero2** (se usaron en pruebas
  locales). Ver [docs/GUIA-USUARIOS.md](docs/GUIA-USUARIOS.md).
- **Configurar desde el panel**: métodos de pago, pisos y mesas, más empleados y un cajero en
  *Permisos básicos*.

## Problemas comunes

| Síntoma | Causa probable |
|---|---|
| Caddy no obtiene certificado | DNS aún no apunta al VPS, o puertos 80/443 cerrados/ocupados |
| `502 Bad Gateway` | Odoo no está `healthy`: `./scripts/prod.sh logs odoo` |
| Login pide elegir base / "database not found" | La base no se llama `odoo_pos` |
| POS no se actualiza en tiempo real | `/websocket` debe ir al puerto 8072 (ya configurado en `config/Caddyfile`) |
| Memoria insuficiente | Bajar `workers` en `config/odoo.prod.conf` y `./scripts/prod.sh restart odoo` |

## Instalar un módulo nuevo (p. ej. `pos_comanda_navegador`)

Con el código ya copiado en `/opt/odoo-restaurant/addons/custom/`:

```bash
cd /opt/odoo-restaurant
./scripts/backup.sh
./scripts/prod.sh restart odoo
./scripts/prod.sh exec odoo odoo -c /tmp/odoo.conf -d odoo_pos -i pos_comanda_navegador --stop-after-init --no-http
./scripts/prod.sh restart odoo
```

Luego, en el panel: **Punto de venta → Configuración → Ajustes** → caja → **Impresora de pedidos**
→ nueva impresora de tipo **"Imprimir por el navegador"** con sus categorías. Las cajas abiertas
deben recargarse (F5).

## Actualizar Odoo en producción

```bash
./scripts/backup.sh
# editar ODOO_IMAGE en .env (p. ej. odoo:19.0-AAAAMMDD)
./scripts/prod.sh pull odoo && ./scripts/prod.sh up -d odoo
./scripts/prod.sh exec odoo odoo -d odoo_pos -u all --stop-after-init --no-http
./scripts/prod.sh restart odoo
```

Nunca usar `docker compose down -v` (borra los volúmenes con todos los datos).

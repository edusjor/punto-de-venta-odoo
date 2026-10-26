# Odoo 19 Community — POS para restaurantes (entorno local)

Entorno de desarrollo para evaluar y personalizar Odoo 19 Community como reemplazo de HIOPOS.

| Componente | Versión fija | Notas |
|---|---|---|
| Odoo | `odoo:19.0-20261015` (imagen oficial) | Publicado solo en `127.0.0.1:8069` |
| PostgreSQL | `postgres:17.11-bookworm` (imagen oficial) | Sin puerto publicado; solo red interna |

Acceso: **http://localhost:8069**

Evaluación de módulos y del flujo de cuentas de cliente: [docs/EVALUACION.md](docs/EVALUACION.md).

## Estructura

```text
odoo-restaurant/
├── docker-compose.yml     # servicios db + odoo, volúmenes, red interna, healthchecks
├── .env                   # credenciales locales (NO se sube a Git)
├── .env.example           # plantilla de .env
├── config/odoo.conf       # configuración de Odoo SIN credenciales
├── addons/custom/         # módulos propios (montado en /mnt/extra-addons/custom)
├── backups/               # respaldos (NO se suben a Git)
├── scripts/               # create-db, configure-db, backup, restore
└── docs/EVALUACION.md
```

### Cómo se manejan las credenciales

`config/odoo.conf` no contiene contraseñas. Al arrancar, el contenedor genera `/tmp/odoo.conf`
(solo dentro del contenedor, permisos 600) añadiendo `db_user`, `db_password` y `admin_passwd`
desde las variables de `.env`. Por eso `docker compose exec odoo odoo ...` usa la misma
configuración que el servidor.

### Persistencia

| Volumen Docker | Contenido |
|---|---|
| `odoo-restaurant_db-data` | Datos de PostgreSQL |
| `odoo-restaurant_odoo-data` | `/var/lib/odoo`: filestore (adjuntos, imágenes), sesiones |

Los volúmenes sobreviven a `docker compose down`, `up --force-recreate` y a los cambios de imagen.
**Nunca use `docker compose down -v`**: borra ambos volúmenes.

## Primer uso (en otro equipo)

```powershell
cd odoo-restaurant
copy .env.example .env      # y edite las contraseñas
docker compose config --quiet   # valida
docker compose up -d
docker compose ps               # ambos servicios deben verse "healthy"
.\scripts\create-db.ps1         # crea odoo_restaurante_dev (es_419, Costa Rica, CRC, America/Costa_Rica)
```

Las bases deben llamarse `odoo_*` (lo exige `dbfilter` en `odoo.conf`).

## Operación diaria

```powershell
docker compose up -d                 # iniciar
docker compose stop                  # detener (conserva contenedores y datos)
docker compose down                  # eliminar contenedores (conserva volúmenes y datos)
docker compose restart odoo          # reiniciar solo Odoo (p. ej. tras cambiar odoo.conf o código Python)
docker compose ps                    # estado y healthchecks
docker compose logs -f odoo          # registros en vivo
docker compose logs --since=1h odoo | Select-String "ERROR|CRITICAL"
```

Los registros se rotan automáticamente (5 archivos de 20 MB por servicio).

## Módulos personalizados

1. Cree el módulo en `addons/custom/<nombre_modulo>/` (con `__manifest__.py`).
2. `docker compose restart odoo`. Mientras `addons/custom/` esté vacío, Odoo muestra el aviso
   `invalid addons directory '/mnt/extra-addons/custom', skipped`; es normal y desaparece con el primer módulo.
3. Instale o actualice el módulo:

```powershell
docker compose exec odoo odoo -d odoo_restaurante_dev -i mi_modulo --stop-after-init --no-http
docker compose exec odoo odoo -d odoo_restaurante_dev -u mi_modulo --stop-after-init --no-http
```

Reglas: nunca modificar el código de Odoo dentro de la imagen; heredar (`_inherit`, herencia de
vistas XML, parches de OWL en `assets`) desde `addons/custom/`. Así una actualización de imagen no
pierde personalizaciones.

## Actualizar Odoo

Odoo publica imágenes con parches de seguridad y corrección de errores (`19.0-AAAAMMDD`).

```powershell
.\scripts\backup.ps1                                 # 1. respaldo SIEMPRE antes
# 2. cambie ODOO_IMAGE en .env (p. ej. odoo:19.0-20261101)
docker compose pull odoo
docker compose up -d odoo
# 3. actualice los módulos de la base
docker compose exec odoo odoo -d odoo_restaurante_dev -u all --stop-after-init --no-http
docker compose restart odoo
```

Pruebe primero sobre una copia restaurada (`restore.ps1 -Database odoo_copia_prueba`).
Pasar a otra versión mayor (19 → 20) **no** es un cambio de imagen: requiere migración de datos
(OpenUpgrade u Odoo Upgrade, servicio Enterprise) y migrar los módulos propios.

PostgreSQL: cambie de parche menor (17.11 → 17.12) solo con `POSTGRES_IMAGE`. Para versión
mayor (17 → 18) haga dump y restauración; no reutilice el volumen.

## Respaldos

```powershell
.\scripts\backup.ps1                                  # base odoo_restaurante_dev
.\scripts\backup.ps1 -Database odoo_eval_credito
```

Genera en `backups\`:

- `<base>_<fecha>.dump`: `pg_dump` en formato custom.
- `<base>_<fecha>_filestore.tgz`: adjuntos e imágenes de productos.

**Ambos archivos son necesarios** para una restauración completa. Copie `backups\` fuera del
equipo (disco externo o nube). Es un directorio con datos de clientes: no lo suba a Git.

Alternativa por interfaz web: http://localhost:8069/web/database/manager → *Backup* (zip con
filestore; requiere la contraseña maestra `ODOO_MASTER_PASSWORD`).

## Restauración

```powershell
.\scripts\restore.ps1 -Dump backups\odoo_restaurante_dev_20261023_120000.dump -Database odoo_restaurante_restaurada
```

- Siempre restaura en una base **nueva**; si el nombre existe, se detiene sin tocar nada.
- Busca automáticamente el `_filestore.tgz` con el mismo nombre (debe estar en `backups\`).
- Para reemplazar la base principal: restaure con otro nombre, verifique y luego, con autorización,
  elimine la antigua desde el gestor de bases de datos.

Si el volumen de PostgreSQL se perdiera por completo: `docker compose up -d` crea uno vacío, y
`restore.ps1` recupera cada base desde los respaldos.

## Credenciales

Todas en `.env` (local):

- `POSTGRES_PASSWORD`: usuario de PostgreSQL (solo red interna).
- `ODOO_MASTER_PASSWORD`: gestor de bases de datos (crear, respaldar, borrar).
- `ODOO_ADMIN_LOGIN` / `ODOO_ADMIN_PASSWORD`: administrador de las bases creadas con `create-db.ps1`.

## Hacia el VPS (pendiente)

- `list_db = False`, `dbfilter` fijo, `proxy_mode = True`.
- `workers > 0` y `gevent_port = 8072`, detrás de Nginx/Traefik con HTTPS (websocket del POS en `/websocket`).
- Contraseñas nuevas y distintas de las locales.
- Respaldos programados (cron) copiados fuera del servidor.

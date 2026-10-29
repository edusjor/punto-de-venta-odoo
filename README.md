# Odoo 19 Community — POS para restaurantes

Odoo 19 Community con Docker como reemplazo de HIOPOS: entorno local y paquete de producción para
VPS ([DEPLOY.md](DEPLOY.md)).

| Componente | Versión fija | Notas |
|---|---|---|
| Odoo | `odoo:19.0-20261015` (imagen oficial) | Local: solo `127.0.0.1:8069` |
| PostgreSQL | `postgres:17.11-bookworm` (imagen oficial) | Sin puerto publicado; solo red interna |
| Caddy (solo producción) | `caddy:2.11.7` | HTTPS automático para `pos.loshinchassportbar.com` |

Acceso local: **http://localhost:8069** · Producción: **https://pos.loshinchassportbar.com** (pendiente de desplegar)

Evaluación de módulos y del flujo de cuentas de cliente: [docs/EVALUACION.md](docs/EVALUACION.md).

## Estado actual

Una sola base de datos, **`odoo_pos`**, idéntica en local y en producción:

| Elemento | Contenido |
|---|---|
| Empresas | **The Club House** (logo, 41 productos en PULPERIA, REFRESCOS, ALIMENTOS, EXTRAS; IVA 13 % incluido) y **Barra Brava Yoses** (solo el nombre, sin productos). Independientes: cada una con su plan contable, impuestos y productos |
| Usuarios | `soporte@cam360cr.com` (administrador total de ambas empresas) y `clubhouse` (cuenta de las tablets de The Club House) |
| Punto de venta | Caja **The Club House** con inicio por empleado: Soporte (avanzado), Mesero1 y Mesero2 (empleados con PIN) |
| Módulos | Punto de venta, Restaurante (mesas), Empleados con PIN (`pos_hr`), localización Costa Rica (`l10n_cr`), `restaurante_login` |
| Vacío | Pedidos y clientes; Barra Brava Yoses sin caja ni empleados |
| Región | Español (`es_419`), Costa Rica, colones (CRC), `America/Costa_Rica` |

`scripts/preparar-base-produccion.ps1` reconstruye la base desde cero (solo empresas, productos y
`soporte`, sin la caja ni `clubhouse`) y deja su respaldo en `backups/`.

## Estructura

```text
odoo-restaurant/
├── docker-compose.yml       # servicios db + odoo, volúmenes, red interna, healthchecks
├── docker-compose.prod.yml  # producción: + Caddy (HTTPS) y odoo.prod.conf
├── .env                     # credenciales técnicas locales (NO se sube a Git)
├── .env.production          # credenciales de producción y de soporte (NO se sube a Git)
├── .env.example             # plantilla de .env
├── config/
│   ├── odoo.conf            # Odoo local, SIN credenciales
│   ├── odoo.prod.conf       # Odoo producción (workers, proxy, dbfilter odoo_pos)
│   └── Caddyfile            # proxy HTTPS
├── addons/custom/           # módulos propios (montado en /mnt/extra-addons/custom)
├── backups/                 # respaldos (NO se suben a Git)
├── scripts/                 # .ps1 (Windows) y .sh (Linux)
├── PRODCUTOS TCH.xlsx       # productos de The Club House
├── DEPLOY.md                # guía de despliegue en el VPS
└── docs/
    ├── EVALUACION.md        # evaluación de módulos y facturación electrónica
    └── GUIA-USUARIOS.md     # paso a paso: usuarios, empleados, PIN, tablets
```

## Credenciales

Ninguna está en Git ni en este README.

| Archivo | Contiene |
|---|---|
| `.env` | Local: contraseña de PostgreSQL y contraseña maestra |
| `.env.production` | Producción: contraseña de PostgreSQL, contraseña maestra, dominio y **usuario, contraseña y PIN de `soporte`** (`ODOO_ADMIN_LOGIN`, `ODOO_ADMIN_PASSWORD`, `ODOO_ADMIN_PIN`). En el VPS se copia como `.env` |

Como la base local es la misma que la de producción, **`soporte` entra en local con la contraseña
de `.env.production`**.

`config/odoo.conf` no contiene contraseñas: al arrancar, el contenedor genera `/tmp/odoo.conf`
(solo dentro del contenedor, permisos 600) con `db_user`, `db_password` y `admin_passwd` desde `.env`.

## Persistencia

| Volumen Docker | Contenido |
|---|---|
| `odoo-restaurant_db-data` | Datos de PostgreSQL |
| `odoo-restaurant_odoo-data` | `/var/lib/odoo`: filestore (logo, adjuntos, imágenes), sesiones |

Los volúmenes sobreviven a `docker compose down`, `up --force-recreate` y a los cambios de imagen.
**Nunca use `docker compose down -v`**: borra ambos volúmenes.

## Primer uso (en otro equipo)

```powershell
cd odoo-restaurant
copy .env.example .env          # y edite las contraseñas
docker compose config --quiet   # valida
docker compose up -d
docker compose ps               # ambos servicios "healthy"
# Opción A: restaurar el respaldo de odoo_pos (copiar antes los 2 archivos a backups\)
.\scripts\restore.ps1 -Dump backups\odoo_pos_AAAAMMDD_HHMMSS.dump -Database odoo_pos
# Opción B: reconstruirla desde cero (requiere .env.production)
.\scripts\preparar-base-produccion.ps1
```

Las bases deben llamarse `odoo_*` (lo exige `dbfilter` en `odoo.conf`). Con más de una base, el
acceso local necesita `?db=<base>` en la URL.

## Operación diaria

```powershell
docker compose up -d                 # iniciar
docker compose stop                  # detener (conserva contenedores y datos)
docker compose down                  # eliminar contenedores (conserva volúmenes y datos)
docker compose restart odoo          # reiniciar solo Odoo (tras cambiar odoo.conf o código Python)
docker compose ps                    # estado y healthchecks
docker compose logs -f odoo          # registros en vivo
docker compose logs --since=1h odoo | Select-String "ERROR|CRITICAL"
```

Los registros se rotan automáticamente (5 archivos de 20 MB por servicio). En el VPS los mismos
comandos se ejecutan con `./scripts/prod.sh` (ver [DEPLOY.md](DEPLOY.md)).

## Usuarios y permisos

El administrador es **`soporte@cam360cr.com`**: Administrador del sistema con acceso a
The Club House y Barra Brava Yoses, y empleado de PdV (nivel gerente) con PIN en ambas. Además
existe `clubhouse`, la cuenta compartida de las tablets de The Club House. Desde el
panel crea los demás usuarios, empleados y PIN. Esta sección es la referencia técnica; el paso a
paso (crear empleado, cuenta de tablet, inicio de sesión y turno) está en
**[docs/GUIA-USUARIOS.md](docs/GUIA-USUARIOS.md)**.

### Dos formas de identificarse

| | **Usuario de Odoo** | **Empleado de PdV** (`pos_hr`) |
|---|---|---|
| Cómo entra | Correo o nombre de usuario + contraseña, en la pantalla de login | Elige su nombre y escribe su **PIN**, dentro de la caja |
| Dónde | Panel de administración ("Backend") y caja | Solo la caja |
| Para quién | Dueño, soporte, gerentes y la cuenta compartida de cada local | Meseros, cajeros, encargados |
| Se crea en | **Ajustes → Usuarios y empresas → Usuarios** | **Empleados** (PIN: pestaña **Ajustes** → **Código NIP**) |

El login acepta correo **o** usuario simple (p. ej. `clubhouse`). "Restablecer contraseña" solo
funciona si el usuario tiene un correo real y hay servidor de correo saliente configurado.

### Roles de usuario de Odoo (panel de administración)

| Rol | Qué puede hacer |
|---|---|
| **Administrador del sistema** (Ajustes) | Todo: usuarios, empresas, módulos, configuración general |
| **Punto de venta: Administrador** | Configurar cajas, mesas, métodos de pago, productos y precios; reportes de ventas |
| **Punto de venta: Usuario** | Usar la caja; ver pedidos y sesiones de su empresa |
| Inventario / Contabilidad | Usuario o Administrador de cada aplicación, por separado |

Cada usuario tiene además las **empresas** a las que accede; solo ve los datos de esas. Tipos de
usuario: **interno** (personal; sin límite ni costo por usuario en Community) y **portal**
(clientes; no sirve para la caja).

### Niveles dentro de la caja (por PIN)

Se configuran por caja en **Punto de venta → Configuración → Ajustes**, sección de empleados.

| Acción | Mesero (mínimo) | Cajero (básico) | Gerente |
|---|---|---|---|
| Pedidos, mesas, enviar a cocina, cobrar en efectivo/tarjeta | ✅ | ✅ | ✅ |
| Descuentos, cambio de precio, devoluciones, borrar pedidos | ❌ | ✅ | ✅ |
| Cobrar a "Cuenta de cliente" (fiado); crear/editar clientes | ❌ | ✅ | ✅ |
| **Abrir la caja** (inicio de turno, efectivo inicial) | ❌ | ✅ | ✅ |
| Entradas y salidas de efectivo | ❌ | ❌ | ✅ |
| **Cerrar la caja** (arqueo de fin de turno) | ❌ | ❌ ⚠️ | ✅ |
| Editar el plano de mesas | ❌ | ❌ | ✅ |

- ⚠️ El **cajero no puede cerrar** la caja: Odoo solo muestra "Cerrar caja" a gerentes o al empleado
  vinculado al usuario que abrió la sesión. Cada local necesita al menos un **encargado con nivel
  gerente** para el cierre diario.
- Un gerente vinculado a un usuario **Administrador de PdV** (p. ej. Soporte) puede además aprobar
  cierres con diferencia mayor a la permitida (si se activa "diferencia máxima" en la caja).
- El botón **"Abrir caja registradora"** de la pantalla inicial solo identifica con PIN; abrir el
  turno es otra cosa (solo cajero o gerente).
- Si nadie toca la pantalla un rato, la caja vuelve a pedir PIN.
- **Importante:** todo empleado asignado a una caja debe tener PIN; sin PIN, cualquiera puede
  elegirlo y entrar con sus permisos.
- Listas de la caja: **Permisos mínimos / básicos / avanzados**. Si *Permisos básicos* está vacía,
  la caja carga **todos** los empleados de la empresa y los no listados entran como cajeros
  (`pos_hr/models/pos_config.py`, `_employee_domain`). Mantener al menos un cajero en esa lista.

### Cuenta compartida por local (recomendado para tablets)

1. Crear una cuenta de Odoo por restaurante (p. ej. `clubhouse`) con rol **Punto de venta:
   Usuario**, acceso solo a su empresa y **sin empleado vinculado**. Conviene que la contraseña la
   conozcan solo los encargados (la sesión queda guardada en cada tablet).
2. Se inicia sesión una vez en el dispositivo; la sesión queda guardada.
3. Dentro de la caja cada persona elige su nombre y pone su **PIN**: los pedidos quedan a su
   nombre y lo que puede hacer depende de su nivel, no de la cuenta compartida.
4. Si alguien deja de trabajar, se **archiva su empleado**; no hace falta cambiar la contraseña compartida.

**Botón "Backend"** (en la caja): vuelve al panel de administración sin cerrar la caja. Pide PIN y
solo deja pasar al empleado vinculado al usuario que inició sesión en ese dispositivo; con una
cuenta compartida (sin empleado) nadie sale al panel con ese botón.

**Limitación conocida:** quien conozca la contraseña compartida puede iniciar sesión desde otro
dispositivo y abrir el panel (con permisos mínimos: ve y edita pedidos de su local; no ve
contabilidad ni configuración). La caja recibe los PIN como SHA-1 sin sal, así que con esa cuenta
un PIN de pocas cifras se puede averiguar: el PIN no sustituye a una contraseña. Mitigaciones: modo kiosco en la tablet (solo protege ese
dispositivo) o un módulo propio que limite esas cuentas a la caja (pendiente).

### Tareas habituales

| Tarea | Dónde |
|---|---|
| Crear usuario / cambiar rol o empresas | **Ajustes → Usuarios y empresas → Usuarios** (o `/odoo/users`) |
| Cambiar contraseña de otro usuario | **Usuarios** → usuario → **⚙ → Cambiar contraseña** |
| Cambiar la propia contraseña | Nombre (arriba a la derecha) → **Mi perfil** → **Seguridad** |
| Crear empleado / cambiar PIN | **Empleados** (o `/odoo/employees`) → empleado → pestaña **Ajustes** → **Código NIP** |
| Asignar empleados y niveles a una caja | **Punto de venta → Configuración → Ajustes** → sección de empleados |
| Dar de baja a un empleado | **Empleados** → empleado → Acción → **Archivar** |
| Crear otra empresa (restaurante) | **Ajustes → Usuarios y empresas → Empresas** (o `scripts/crear-compania.py`) |

## Módulos personalizados

1. Cree el módulo en `addons/custom/<nombre_modulo>/` (con `__manifest__.py`).
2. `docker compose restart odoo`.
3. Instale o actualice el módulo:

```powershell
docker compose exec odoo odoo -d odoo_pos -i mi_modulo --stop-after-init --no-http
docker compose exec odoo odoo -d odoo_pos -u mi_modulo --stop-after-init --no-http
```

Reglas: nunca modificar el código de Odoo dentro de la imagen; heredar (`_inherit`, herencia de
vistas XML, parches de OWL en `assets`) desde `addons/custom/`. Así una actualización de imagen no
pierde personalizaciones.

| Módulo | Qué hace |
|---|---|
| `restaurante_login` | Login simplificado: campo "Correo electrónico o usuario", sin registro libre, sin llave de acceso, sin "Gestionar bases de datos" ni "Con la tecnología de Odoo". Mantiene "Restablecer contraseña" |
| `pos_comanda_navegador` | Tipo de impresora de pedidos **"Imprimir por el navegador"**: las comandas de cocina salen por el diálogo de impresión del dispositivo (cualquier impresora o PDF) en lugar de una Epson ePOS o caja IoT. Mantiene el flujo nativo (botón Enviar, solo lo nuevo, por categorías). Para pruebas o locales sin térmica |

## Scripts

| Script | Uso |
|---|---|
| `preparar-base-produccion.ps1` | Construye `odoo_pos` desde cero (empresas, productos, `soporte`) y la respalda |
| `import-productos.py` | Importa/actualiza productos desde el Excel en la empresa activa |
| `crear-compania.py` | Crea un restaurante como empresa independiente (Costa Rica, CRC, IVA) |
| `configure-db.py`, `setup-admin-produccion.py` | Pasos internos de `preparar-base-produccion.ps1` |
| `create-db.ps1` | Crea una base vacía (es_419, Costa Rica) con `restaurante_login` |
| `backup.ps1` / `backup.sh` | Respaldo: base + filestore en `backups/` (`.sh` con rotación, para cron) |
| `restore.ps1` / `restore.sh` | Restaura un respaldo en una base **nueva** (nunca sobrescribe) |
| `prod.sh` | `docker compose` con la configuración de producción |
| `setup-empleados-pos.py` | Opcional: crea un cajero y dos meseros de ejemplo por caja, con PIN al azar |

## Actualizar Odoo

Odoo publica imágenes con parches de seguridad y corrección de errores (`19.0-AAAAMMDD`).

```powershell
.\scripts\backup.ps1                                 # 1. respaldo SIEMPRE antes
# 2. cambie ODOO_IMAGE en .env (p. ej. odoo:19.0-20261101)
docker compose pull odoo
docker compose up -d odoo
# 3. actualice los módulos de la base
docker compose exec odoo odoo -d odoo_pos -u all --stop-after-init --no-http
docker compose restart odoo
```

Pruebe primero sobre una copia restaurada. Pasar a otra versión mayor (19 → 20) **no** es un
cambio de imagen: requiere migración de datos (OpenUpgrade u Odoo Upgrade, servicio Enterprise) y
migrar los módulos propios. PostgreSQL: parche menor (17.11 → 17.12) solo con `POSTGRES_IMAGE`;
versión mayor (17 → 18) con dump y restauración.

## Respaldos y restauración

```powershell
.\scripts\backup.ps1                                  # base odoo_pos
.\scripts\restore.ps1 -Dump backups\odoo_pos_AAAAMMDD_HHMMSS.dump -Database odoo_pos_copia
```

- Genera `<base>_<fecha>.dump` (`pg_dump`) y `<base>_<fecha>_filestore.tgz` (logo, adjuntos):
  **ambos son necesarios**.
- La restauración siempre va a una base **nueva**; si el nombre existe, se detiene sin tocar nada.
- Copie `backups\` fuera del equipo. Contiene datos del negocio: no lo suba a Git.
- El gestor de bases por web está deshabilitado (`list_db = False`); todo se hace con los scripts.
- Para reemplazar una base: restaure con otro nombre, verifique y luego elimine la antigua:
  `docker compose exec db sh -c 'dropdb -U $POSTGRES_USER --force <base>'`.

## Producción (VPS)

Preparado, pendiente de desplegar. Instrucciones completas en [DEPLOY.md](DEPLOY.md).

| Archivo | Uso |
|---|---|
| `docker-compose.prod.yml` | Añade Caddy (HTTPS automático) y usa `config/odoo.prod.conf` |
| `config/odoo.prod.conf` | `dbfilter = ^odoo_pos$`, `proxy_mode`, 2 workers + websocket en 8072 |
| `config/Caddyfile` | Proxy HTTPS para `ODOO_DOMAIN` |
| `.env.production` | Secretos de producción (en el VPS se copia como `.env`) |
| `backups/odoo_pos_*` | Respaldo de `odoo_pos` que se restaura en el VPS |

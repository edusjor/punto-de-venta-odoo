# Evaluación inicial: Odoo 19 Community para POS de restaurante

Fecha: 2026-10-23 · Imagen evaluada: `odoo:19.0-20261015` (692 módulos incluidos).

Método: inspección del código fuente dentro de la imagen, instalación real de los módulos y
ejecución del flujo de crédito con el ORM en la base `odoo_eval_credito` (datos ficticios).
"Verificado" significa que se instaló o ejecutó; "código" significa que se leyó en el fuente.

## 1. Módulos (todos LGPL-3, incluidos en Community)

| Necesidad | Módulo(s) Community | Estado |
|---|---|---|
| Punto de venta | `point_of_sale` | Verificado: instalado, sesión abierta y cerrada |
| Productos y categorías | `product`, categorías POS (`pos.category`) | Verificado |
| Clientes | `contacts`, `res.partner` | Verificado |
| Métodos de pago | `pos.payment.method`: efectivo, banco, **Cuenta de cliente** (`pay_later`) | Verificado |
| Ventas | `sale_management`, `pos_sale` | Verificado: instalado |
| Apertura y cierre de caja | `point_of_sale` (control de efectivo, diferencia máxima permitida) | Verificado |
| Reportes de ventas | Análisis de pedidos POS, reporte *Detalles de ventas* (`report_saledetails`) | Código |
| Control de usuarios | Grupos POS usuario/administrador; `pos_hr`: cajeros con PIN o gafete | Verificado: instalado |
| Descuentos | `pos_discount` (global), descuento por línea nativo | Verificado: instalado |
| Inventario | `stock`, `stock_account` | Verificado: instalado |
| Cuentas por cobrar | `account` (Facturación) | Verificado: ver sección 2 |
| Mesas y restaurante | `pos_restaurant`: pisos, mesas, dividir cuenta, pre-cuenta, propinas, impresoras de cocina | Verificado: instalado |
| Restaurante + empleados | `pos_hr_restaurant` | Verificado: instalado |
| Autopedido (QR o kiosco) | `pos_self_order` | Verificado: instalado |
| Lealtad, cupones, tarjetas regalo | `pos_loyalty` | Verificado: instalado |
| Localización CR | `l10n_cr`: plan de cuentas e IVA 13 % (venta y compra) | Verificado: se instala automáticamente |

### No incluido en Community (Enterprise o terceros)

Comprobado: estos módulos **no existen** en la imagen.

| Función | Módulo | Alternativa en Community |
|---|---|---|
| Cobrar deudas desde el POS ("Settle due") | `pos_settle_due` (Enterprise; `point_of_sale` lo ofrece como *upsell*) | Registrar el abono en Facturación, o desarrollar un módulo propio |
| Pantalla de cocina (KDS) | `pos_preparation_display` (Enterprise) | Comandas impresas con `pos_restaurant` |
| IoT Box (balanzas, impresoras USB, gaveta por IoT) | `iot`, `pos_iot` (Enterprise) | Impresoras Epson ePOS por red (`epson_epos`), sin IoT |
| Contabilidad completa: libro mayor de clientes, antigüedad de saldos, conciliación manual | `account_accountant`, `account_reports` (Enterprise) | Apuntes contables filtrados por cliente; módulos OCA |
| Seguimiento de cobros (recordatorios) | `account_followup` (Enterprise) | Módulos OCA (`account_credit_control`) |
| Studio | `web_studio` (Enterprise) | Módulos propios |
| Facturación electrónica de Costa Rica | Ninguno oficial | Ver sección 3 |

### Impresión térmica

- Recibo: impresión desde el navegador (cualquier impresora instalada en Windows) o directa a impresoras Epson con ePOS por red (`pos.printer`, tipo `epson_epos`).
- Comandas de cocina: `pos_restaurant`, con impresoras Epson ePOS por red.
- Impresoras USB o no Epson sin diálogo del navegador: requieren IoT Box (Enterprise) o un desarrollo propio.

## 2. Cuentas de cliente (crédito y abonos): resultado de la prueba

Escenario ejecutado en `odoo_eval_credito`: método "Cuenta de cliente" (`split_transactions=True`,
sin diario), cliente con límite de crédito de ₡20 000 y venta de "Casado de pollo" a ₡4 500 + IVA 13 %.

| Paso | ¿Nativo? | Resultado real |
|---|---|---|
| 1. Crear cliente | Sí | Desde el POS o desde el backend |
| 2-3. Venta asociada al cliente | Sí | El POS **exige** cliente al usar "Cuenta de cliente" |
| 4. Dejar pendiente de pago | Sí | Orden A sin factura (₡10 170) y orden B con factura (₡15 255) |
| 5. Consultar saldo | **Parcial** | `Por cobrar` del cliente = ₡25 425 después del cierre de caja. Antes del cierre solo reflejaba la venta facturada (₡15 255) |
| 6. Abono parcial | Sí, **solo en el backend** | Factura: *Registrar pago* de ₡5 000 → estado "Parcial", saldo ₡10 255. Sin factura: *Registrar pago* sobre el apunte contable de la sesión, ₡3 000 → saldo ₡7 170 |
| 7. Historial de movimientos | **Parcial** | Lista de apuntes por cobrar del cliente (cargos y abonos con saldo restante). Requiere activar "funciones contables completas". No hay estado de cuenta imprimible para el cliente |
| 8. Liquidar deuda | Sí, backend | Factura "Pagada", apunte residual 0, saldo del cliente 0 |

### Limitaciones detectadas

1. **El límite de crédito no se aplica en el POS.** El cliente con límite de ₡20 000 quedó debiendo ₡25 425 sin aviso. Community solo muestra un aviso (no bloquea) en facturas y pedidos de venta del backend.
2. **El cajero no ve el saldo del cliente en el POS.** La columna de saldo de la lista de clientes queda vacía en Community (`partner_line.xml`: *"FIXME: this should be in pos_settle_due"*).
3. **No se pueden recibir abonos en el POS.** Es la función de `pos_settle_due` (Enterprise). Hoy el abono se registra en Facturación y no entra en el arqueo de la caja POS.
4. **Ventas a crédito sin factura:** la deuda solo aparece en el saldo del cliente al cerrar la sesión. Al cierre se agrupa en un asiento de sesión (una línea por pago a crédito), lo que hace menos claro el historial. **Recomendación:** facturar siempre las ventas a crédito (documento por venta, abonos sobre la factura y saldo inmediato).
5. **Sin estado de cuenta imprimible** ni libro de clientes (Enterprise `account_reports`).

### Personalización probable (módulo propio, no desarrollado todavía)

- `pos_customer_account` (nombre tentativo):
  - Mostrar el saldo en la pantalla de clientes del POS.
  - Bloquear o pedir autorización de supervisor al superar el límite de crédito.
  - Registrar abonos desde el POS dentro del arqueo de caja.
  - Forzar factura en las ventas a crédito.
  - Imprimir en térmica el estado de cuenta y el comprobante de abono.
- Alternativa: evaluar módulos OCA del repositorio `OCA/pos` para 19.0 antes de desarrollar.

## 3. Facturación electrónica Costa Rica (Hacienda, v4.4)

**Estado: no implementada. No se instaló nada fiscal ni se envió ningún comprobante.**

- Odoo S.A. **no ofrece** conector con Hacienda, ni en Community ni en Enterprise. Costa Rica no tiene página de localización en la documentación 19.0, y en la imagen no existe ningún `l10n_cr_edi`. `l10n_cr` solo trae el plan de cuentas y los impuestos.
- La versión 4.4 de comprobantes es obligatoria desde el 1-sep-2025. Hacienda publicó ajustes a los Anexos y Estructuras v4.4 (bitácora 22-abr-2026) obligatorios desde el **1-nov-2026**.

Alternativas encontradas (no instaladas; verificar con cada proveedor):

| Opción | Tipo | Versión Odoo | Notas |
|---|---|---|---|
| `akurey/l10n_cr` (fork de `odoocr/l10n_cr`) | Libre, AGPL-3 | Rama 19.0 existente | Incluye `cr_electronic_invoice` y `cr_electronic_invoice_pos` (tiquete desde el POS). El README indica 4.3 y que la rama 19.0 **"no está funcional"** (en migración). Hay PRs recientes con códigos v4.4 de 2026 |
| CRLibre `fe-hacienda-cr-odoo` | Libre | Por verificar | Proyecto comunitario de referencia |
| Factico (Odoo Apps) | Comercial + suscripción mensual a su API | 18 y 19 | Community y Enterprise |
| Xalachi `l10n_cr_invoice` (Odoo Apps) | Comercial | 17 (por verificar 19) | Declara v4.4 y Community |
| Partners (Vauxoo, Nimetrix, etc.) | Servicio | Varía | Localización con soporte |

Dependencias típicas de cualquier opción:

- Llave criptográfica (.p12) y PIN del ATV.
- Usuario y clave de la API de Hacienda (ambiente de pruebas y de producción).
- Actividad económica (CIIU 4), códigos CABYS por producto y consecutivos por sucursal y terminal.
- Tiquete electrónico desde el POS (con contingencia sin conexión).
- Notas de crédito y mensajes de aceptación.

Decisión pendiente: libre (más desarrollo y mantenimiento propio) o comercial (costo recurrente y dependencia del proveedor).

## 4. Bases de datos

La única base activa es `odoo_pos` (idioma `es_419`; Odoo no tiene `es_CR`): The Club House con
sus productos, Barra Brava Yoses sin productos y un único usuario administrador. Ver el README.

Las bases anteriores se eliminaron y quedan solo como respaldo local (los respaldos no se suben a Git):

- `odoo_eval_credito` (prueba de crédito y POS de mesas, eliminada el 2026-10-27):
  `backups/odoo_eval_credito_20261023_115607.dump`.
- `odoo_restaurante_dev` (4 restaurantes y usuarios de demostración, eliminada el 2026-10-28):
  `backups/odoo_restaurante_dev_20261028_120816.dump`.

Fuentes de la sección 3:

- [Odoo 19 – Localizaciones fiscales](https://www.odoo.com/documentation/19.0/applications/finance/fiscal_localizations.html)
- [akurey/l10n_cr](https://github.com/akurey/l10n_cr)
- [PR #156: códigos de referencia 2026 v4.4](https://github.com/akurey/l10n_cr/pull/156)
- [CRLibre fe-hacienda-cr-odoo](https://github.com/automatuanis/fe-hacienda-cr-odoo)
- [l10n_cr_invoice 19.0 (Odoo Apps)](https://apps.odoo.com/apps/modules/19.0/l10n_cr_invoice)
- [KPMG: prórroga v4.4](https://kpmg.com/us/en/taxnewsflash/news/2025/02/tnf-costa-rica-deadline-changes-e-invoices-extended.html)

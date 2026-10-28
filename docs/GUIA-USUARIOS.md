# Guía: usuarios, empleados e inicio de sesión

Para quien administra el sistema (hoy, la cuenta `soporte`). Explica cómo dar acceso al personal de
cada restaurante. Los nombres de botones y menús son los que aparecen en pantalla.

## 1. Usuario y empleado: la diferencia

| | **Usuario** | **Empleado** |
|---|---|---|
| Qué es | Una **cuenta para iniciar sesión** en Odoo (usuario o correo + contraseña) | Una **persona del personal**, con su **PIN** |
| Para qué sirve | Abrir Odoo en una tablet o computadora | Identificarse **dentro de la caja** ya abierta |
| Ejemplos | `soporte`, `clubhouse` (la cuenta de las tablets) | Meseros, cajeros, encargados |
| Dónde se crea | **Ajustes → Usuarios y empresas → Usuarios** | **Empleados** |

En corto: **el usuario abre la tablet; el empleado dice quién la está usando.**

Un mesero **no necesita usuario**: solo se crea como empleado con PIN. La tablet se abre con la
cuenta compartida del restaurante (`clubhouse`).

| Persona | ¿Usuario? | ¿Empleado? |
|---|---|---|
| Mesero, cajero | No | Sí |
| Encargado que solo trabaja en la caja | No | Sí |
| Encargado que además revisa reportes en el panel | Sí | Sí, vinculado a su usuario |
| Cuenta de las tablets (`clubhouse`) | Sí | **No** |

## 2. Llegar rápido a cada pantalla

- **Cuadritos ⋮⋮⋮** (arriba a la izquierda) → lista de apps. **Ajustes** es la última.
- **Ctrl + K** y escribir con **barra**: `/usuarios`, `/empleados`, `/punto de venta`.
- **Marcadores** (abrir la pantalla una vez y pulsar Ctrl + D):

| Pantalla | Dirección |
|---|---|
| Usuarios | `https://pos.loshinchassportbar.com/odoo/users` |
| Empleados | `https://pos.loshinchassportbar.com/odoo/employees` |

En el equipo local, cambie el inicio por `http://localhost:8069`.

**Ojo:** *Empleados → Configuración → Ajustes* se parece a la pantalla de Ajustes, pero es otra:
ahí **no** está el menú *Usuarios y empresas*.

Antes de crear cualquier cosa, revise **arriba a la derecha** que esté activa la empresa correcta
(The Club House o Barra Brava Yoses). Cada restaurante tiene sus propios empleados y cajas; no se
comparten.

## 3. Crear un empleado (mesero, cajero o encargado)

1. **Empleados → Nuevo**.
2. **Nombre** del empleado. Lo demás (correo, teléfono, puesto) es opcional.
3. Pestaña **Ajustes**:
   - **Usuario**: déjelo **vacío** (salvo el caso del encargado con usuario, sección 6).
   - **Código NIP**: el PIN, por ejemplo 4 números. **Distinto para cada persona.**
4. Guardar (ícono de nube arriba).
5. Darle acceso a la caja (sección 4). **Sin ese paso no aparece en la caja.**

## 4. Dar acceso a una caja y elegir el nivel

**Punto de venta → Configuración → Ajustes** → elegir la caja arriba (campo *Punto de venta*) →
**Iniciar sesión como empleado** (activado) → poner a cada empleado en una lista:

| Lista | Para | Qué puede hacer |
|---|---|---|
| **Permisos mínimos** | Meseros | Mesas, pedidos, enviar a cocina, cobrar. **No**: abrir ni cerrar caja, descuentos, cambiar precios, devoluciones, fiado, editar clientes, mover efectivo |
| **Permisos básicos** | Cajeros | Lo anterior + descuentos, devoluciones, fiado, clientes y **abrir** la caja. **No puede cerrarla** |
| **Permisos avanzados** | Encargados, Soporte | Todo, incluido **cerrar** la caja y mover efectivo |

Guardar al terminar.

**Importante:** mientras **Permisos básicos** esté vacía (dice "Todos los empleados"), **cualquier**
empleado de esa empresa puede entrar a la caja, y los que no estén en ninguna lista entran como
cajeros. Ponga al menos un cajero en *Permisos básicos*: así solo entran los de las listas.

Las listas son **por caja**: si crea otra caja, llene también las suyas.

## 5. Crear la cuenta de las tablets (una por restaurante)

Se hace una sola vez por restaurante.

1. **Ajustes → Usuarios y empresas → Usuarios → Nuevo**.
2. **Nombre**: `Tablet Club House`. **Usuario**: `clubhouse` (no hace falta que sea un correo).
3. Pestaña **Permisos de acceso**:
   - **Función**: Usuario.
   - **Empresas** y **Empresa predeterminada**: solo su restaurante.
   - **Punto de venta**: Usuario.
   - Lo demás: No.
4. Guardar. Luego **⚙ → Cambiar contraseña** y escribir la contraseña de las tablets.
5. **No** vincular ningún empleado a esta cuenta.

## 6. Crear un usuario para alguien que entra al panel

Solo para quien deba ver reportes o configurar desde una computadora (dueño, gerente).

1. Crear el **usuario** como en la sección 5, con su correo real (sirve para "Restablecer
   contraseña"), y en **Punto de venta** elegir:
   - **Usuario**: ve pedidos y usa la caja.
   - **Administrador**: además configura cajas, mesas, productos y precios, y ve reportes.
2. Crear su **empleado** (sección 3) y, en la pestaña **Ajustes**, elegir su usuario en el campo
   **Usuario**.
3. Ponerlo en **Permisos avanzados** de la caja si va a cerrarla.

**Función: Administrador** da control total del sistema (usuarios, empresas, todo). Déjelo solo
para soporte.

## 7. Iniciar sesión en una tablet y el turno diario

**Primera vez en cada tablet** (lo hace el encargado):

1. Abrir `https://pos.loshinchassportbar.com` en el navegador.
2. Escribir `clubhouse` y su contraseña. La sesión queda guardada; no se vuelve a pedir salvo que
   alguien cierre sesión o se cambie la contraseña.

**Cada día:**

1. **Abrir la caja** (solo cajero o encargado): Punto de venta → caja → **Abrir**, elegir su nombre,
   PIN, y contar el efectivo inicial.
2. **Meseros**: toman una tablet, eligen su nombre y escriben su PIN. Varias tablets pueden usar la
   misma caja abierta al mismo tiempo.
3. **Cambio de persona**: tocar el nombre del empleado actual (arriba) y elegir otro con su PIN.
4. **Cerrar la caja** (solo **Permisos avanzados**): **Cerrar caja**, contar el efectivo y confirmar.

## 8. Tareas frecuentes

| Tarea | Dónde |
|---|---|
| Cambiar el PIN de alguien | **Empleados** → empleado → pestaña **Ajustes** → **Código NIP** |
| Dar de baja a un empleado | **Empleados** → empleado → **⚙ → Archivar** (no eliminar: se pierde el historial) |
| Cambiar la contraseña de las tablets | **Usuarios** → `clubhouse` → **⚙ → Cambiar contraseña**. Cierra la sesión en **todas** las tablets |
| Cambiar la propia contraseña | Su nombre o foto (arriba a la derecha) → **Mi perfil** o **Mis preferencias** → **Seguridad** |
| Cambiar el nivel de un empleado | **Punto de venta → Configuración → Ajustes** → caja → moverlo de lista |

## 9. Seguridad de la cuenta compartida

- Que la contraseña de `clubhouse` la conozcan **pocas personas** (idealmente solo encargados).
  Con ella se puede entrar desde cualquier lugar con internet.
- **Cámbiela** si se va alguien que la conocía o se pierde una tablet.
- El PIN **no** es una protección fuerte: alguien con conocimientos técnicos y la contraseña de
  `clubhouse` podría averiguar los PIN. El PIN de un encargado nunca debe ser igual a ninguna
  contraseña.
- Bloqueo de pantalla en las tablets.
- Descuentos y devoluciones quedan registrados con el nombre del empleado: revíselos en
  **Punto de venta → Reportes**.

## 10. Errores comunes

| Problema | Causa / solución |
|---|---|
| El empleado no aparece en la caja | No está en ninguna lista de la caja, es de otra empresa, o la caja no se recargó tras guardar |
| Aparecen empleados que no deberían | *Permisos básicos* está vacía (sección 4) |
| El mesero no puede abrir o cerrar la caja | Es lo esperado: abrir = básico o avanzado; cerrar = solo avanzado |
| Creé un usuario para un mesero | No hacía falta. Vacíe el campo **Usuario** del empleado, guarde, y **archive** el usuario. **No elimine el empleado** |
| "Restablecer contraseña" no llega | El usuario no tiene correo real o falta configurar el correo saliente |

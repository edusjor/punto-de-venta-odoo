# Ejecutar con: odoo shell -d <base> --no-http < configure-db.py
# Ajusta la compañía (The Club House) a Costa Rica / CRC y la zona
# horaria de todos los usuarios internos. Si el PdV está instalado, los
# usuarios (actuales y nuevos) entran directo al tablero de Punto de venta
# y sin el chat de bienvenida de OdooBot.
crc = env.ref("base.CRC")
crc.active = True
company = env.company
if company.currency_id != crc:
    # Solo es posible mientras no haya asientos contables
    company.currency_id = crc
company.write({
    "name": "The Club House",
    "country_id": env.ref("base.cr").id,
    "city": "San José",
})
users = env["res.users"].search([("share", "=", False)])
users.write({"tz": "America/Costa_Rica"})

pos_home = env.ref("point_of_sale.action_pos_config_kanban", raise_if_not_found=False)
if pos_home:
    users.write({"action_id": pos_home.id})
    env["ir.default"].set("res.users", "action_id", pos_home.id)
if "odoobot_state" in users._fields:
    users.write({"odoobot_state": "disabled"})
    env["ir.default"].set("res.users", "odoobot_state", "disabled")
env.cr.commit()
l10n = env["ir.module.module"].search([("name", "=like", "l10n_%"), ("state", "=", "installed")])
print("Compañía:", company.name, "| moneda:", company.currency_id.name,
      "| país:", company.country_id.code,
      "| localización:", ", ".join(l10n.mapped("name")) or "-")
print("Inicio de usuarios:", pos_home.display_name if pos_home else "- (PdV no instalado)")

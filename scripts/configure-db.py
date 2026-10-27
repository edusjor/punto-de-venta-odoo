# Ejecutar con: odoo shell -d <base> --no-http < configure-db.py
# Ajusta la compañía (The Club House) a Costa Rica / CRC y la zona
# horaria de todos los usuarios internos.
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
env["res.users"].search([("share", "=", False)]).write({"tz": "America/Costa_Rica"})
env.cr.commit()
l10n = env["ir.module.module"].search([("name", "=like", "l10n_%"), ("state", "=", "installed")])
print("Compañía:", company.name, "| moneda:", company.currency_id.name,
      "| país:", company.country_id.code,
      "| localización:", ", ".join(l10n.mapped("name")) or "-")

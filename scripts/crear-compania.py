# Ejecutar con: odoo shell -d <base> --no-http < crear-compania.py
# Variables de entorno: COMPANY_NAME y (opcional) ADMIN_PIN.
# Crea un restaurante como compañía independiente: Costa Rica, CRC, plan
# contable l10n_cr con IVA 13 %. Da acceso al administrador y le crea su
# empleado de PdV en esa compañía con el mismo PIN. Volver a ejecutarlo no
# duplica nada.
import os

name = os.environ["COMPANY_NAME"]
admin = env.ref("base.user_admin")
Company = env["res.company"]

company = Company.search([("name", "=", name)], limit=1) or Company.create({
    "name": name,
    "country_id": env.ref("base.cr").id,
    "currency_id": env.ref("base.CRC").id,
    "city": "San José",
})
admin.write({"company_ids": [(4, company.id)]})

if not company.chart_template:
    env["account.chart.template"].try_loading("cr", company=company, install_demo=False)

Emp = env["hr.employee"].with_context(active_test=False)
emp = Emp.search([("user_id", "=", admin.id), ("company_id", "=", company.id)], limit=1) or \
    Emp.create({"name": admin.name, "user_id": admin.id, "company_id": company.id, "work_email": admin.login})
if os.environ.get("ADMIN_PIN"):
    emp.pin = os.environ["ADMIN_PIN"]

env.cr.commit()
taxes = env["account.tax"].search([("company_id", "=", company.id), ("type_tax_use", "=", "sale")])
print("Compañía:", company.name, "| moneda:", company.currency_id.name, "| país:", company.country_id.code,
      "| impuestos venta:", taxes.mapped("name"))
print("Acceso de", admin.login, ":", admin.company_ids.mapped("name"), "| empleado PdV:", emp.name, "PIN:", bool(emp.pin))

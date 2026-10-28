# Ejecutar con: odoo shell -d <base> --no-http < setup-admin-produccion.py
# Variables de entorno: ADMIN_PIN, BASE_URL y (opcional) /tmp/company_logo.b64.
# Deja al administrador como único usuario interno ("Soporte"), con PIN para
# el PdV, y fija la URL pública de la base.
import os

admin = env.ref("base.user_admin")
admin.write({"name": "Soporte", "email": admin.login, "lang": "es_419", "tz": "America/Costa_Rica"})

emp = admin.employee_ids[:1] or env["hr.employee"].create({"name": "Soporte", "user_id": admin.id})
emp.write({"name": "Soporte", "pin": os.environ["ADMIN_PIN"], "work_email": admin.login})

if os.path.exists("/tmp/company_logo.b64"):
    env.company.logo = open("/tmp/company_logo.b64", "rb").read()

ICP = env["ir.config_parameter"].sudo()
ICP.set_param("web.base.url", os.environ["BASE_URL"])
# Evita que Odoo reemplace la URL pública por la del primer acceso de un admin
ICP.set_param("web.base.url.freeze", "True")

env.cr.commit()
internos = env["res.users"].search([("share", "=", False)])
print("Usuarios internos:", internos.mapped("login"))
print("Empleado PdV:", emp.name, "| PIN definido:", bool(emp.pin))
print("Compañías:", env["res.company"].search([]).mapped("name"), "| logo:", bool(env.company.logo))
print("URL:", ICP.get_param("web.base.url"))

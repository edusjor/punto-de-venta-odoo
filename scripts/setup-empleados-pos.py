# Ejecutar con: odoo shell -d <base> --no-http < setup-empleados-pos.py
# Requiere pos_hr. Activa el inicio de sesión por PIN en todas las cajas y crea,
# por cada caja, un cajero (acceso básico) y dos meseros (acceso mínimo) con
# nombres provisionales. Los PIN se generan al azar y se muestran al final; el
# empleado del administrador también recibe PIN para que nadie entre como
# gerente sin clave. Volver a ejecutarlo no duplica empleados ni cambia PIN.
import secrets

Employee = env["hr.employee"].with_context(active_test=False)
used_pins = set(Employee.search([("pin", "!=", False)]).mapped("pin"))


def new_pin():
    while True:
        pin = f"{secrets.randbelow(10000):04d}"
        if pin not in used_pins:
            used_pins.add(pin)
            return pin


def employee(name, company):
    # Cada local es una compañía: el empleado debe ser de la compañía de su caja
    emp = Employee.search([("name", "=", name)], limit=1) or Employee.create({"name": name, "company_id": company.id})
    if emp.company_id != company:
        emp.company_id = company
    if not emp.pin:
        emp.pin = new_pin()
    return emp


# El admin tiene un empleado por compañía: todos con el mismo PIN
admin_emps = Employee.search([("user_id", "=", env.ref("base.user_admin").id)])
admin_pin = next(iter(admin_emps.filtered("pin").mapped("pin")), None) or new_pin()
admin_emps.filtered(lambda e: not e.pin).write({"pin": admin_pin})

for config in env["pos.config"].search([]):
    local = config.name.replace("Barra Brava ", "")
    cajero = employee(f"Cajero {local}", config.company_id)
    meseros = employee(f"Mesero 1 {local}", config.company_id) | employee(f"Mesero 2 {local}", config.company_id)
    config.write({
        "module_pos_hr": True,
        # Con basic_employee_ids no vacío, la caja solo carga sus propios empleados
        "basic_employee_ids": [(4, cajero.id)],
        "minimal_employee_ids": [(4, e.id) for e in meseros],
    })

env.cr.commit()
for config in env["pos.config"].search([]):
    print(f"\n{config.name}")
    for label, emps in (("Gerente", config.advanced_employee_ids), ("Cajero", config.basic_employee_ids),
                        ("Mesero", config.minimal_employee_ids)):
        for e in emps:
            print(f"  {label:8} {e.name:28} PIN {e.pin}   ({e.company_id.name})")

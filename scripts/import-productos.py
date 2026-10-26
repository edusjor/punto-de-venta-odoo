# Ejecutar con: odoo shell -d <base> --no-http < import-productos.py
# Lee /tmp/productos.xlsx (columnas PRODUCTOS, PRECIO, CARPETA; la carpeta solo
# se escribe en la primera fila de cada grupo), crea una categoría de PdV por
# carpeta y los productos con precio IVA incluido. Archiva los productos y
# categorías de demostración de point_of_sale / pos_restaurant.
# Volver a ejecutarlo actualiza precios y categorías sin duplicar.
import re

import openpyxl

XLSX = "/tmp/productos.xlsx"


def clean(text):
    return re.sub(r"\s+", " ", str(text)).strip(" ,")


# --- Leer hoja ---
ws = openpyxl.load_workbook(XLSX, data_only=True).active
rows, folder = [], None
for name, price, carpeta in ws.iter_rows(min_row=2, max_col=3, values_only=True):
    if carpeta:
        folder = clean(carpeta)
    if name and price is not None:
        rows.append((folder, clean(name), float(price)))

# --- Impuesto 13 % con precio incluido (el precio de la hoja es el precio final) ---
Tax = env["account.tax"]
tax = Tax.search([("type_tax_use", "=", "sale"), ("amount", "=", 13),
                  ("price_include_override", "=", "tax_included"),
                  ("company_id", "=", env.company.id)], limit=1)
if not tax:
    base_tax = Tax.search([("type_tax_use", "=", "sale"), ("amount", "=", 13),
                           ("company_id", "=", env.company.id)], limit=1)
    tax = base_tax.copy({"name": "13% IVA incluido", "price_include_override": "tax_included"})

# --- Categorías de PdV (las "carpetas") ---
PosCateg = env["pos.category"]
categs = {}
for seq, folder in enumerate(dict.fromkeys(f for f, _, _ in rows), start=1):
    categ = PosCateg.search([("name", "=", folder)], limit=1) or PosCateg.create({"name": folder})
    categ.sequence = seq
    categs[folder] = categ

# --- Productos ---
Product = env["product.template"].with_context(active_test=False)
created = updated = 0
for seq, (folder, name, price) in enumerate(rows, start=1):
    categ = categs[folder]
    vals = {
        "name": name,
        "list_price": price,
        "type": "consu",
        "sale_ok": True,
        "available_in_pos": True,
        "active": True,
        "pos_categ_ids": [(6, 0, categ.ids)],
        "taxes_id": [(6, 0, tax.ids)],
        "sequence": seq,
    }
    product = Product.search([("name", "=", name), ("pos_categ_ids", "in", categ.ids)], limit=1)
    if product:
        product.write(vals)
        updated += 1
    else:
        Product.create(vals)
        created += 1

# --- Quitar datos de demostración ---
demo_modules = ("point_of_sale", "pos_restaurant")
imd = env["ir.model.data"].search([("module", "in", demo_modules),
                                   ("model", "in", ("product.template", "pos.category", "product.combo"))])
demo = {m: env[m].browse(imd.filtered(lambda d: d.model == m).mapped("res_id")).exists()
        for m in ("product.template", "pos.category", "product.combo")}
tip = env.ref("point_of_sale.product_product_tip_product_template", raise_if_not_found=False)
demo_products = demo["product.template"] - (tip or Product)
# Los combos impiden archivar los productos que contienen
demo_products.filtered(lambda p: p.type == "combo").write({"active": False, "available_in_pos": False})
for combo in demo["product.combo"]:
    try:
        with env.cr.savepoint():
            combo.unlink()
    except Exception:
        combo.active = False
deleted = archived = 0
for product in demo_products.filtered("active"):
    try:
        with env.cr.savepoint():
            product.unlink()
        deleted += 1
    except Exception:
        # Usado en pedidos o con una sesión de PdV abierta: se archiva
        product.write({"active": False, "available_in_pos": False})
        archived += 1
demo_categs = demo["pos.category"] - PosCateg.browse([c.id for c in categs.values()])
for categ in demo_categs:
    try:
        with env.cr.savepoint():
            categ.unlink()
    except Exception:
        pass

# --- Mostrar solo las categorías nuevas en los PdV que limitan categorías ---
for config in env["pos.config"].search([("limit_categories", "=", True)]):
    config.iface_available_categ_ids = [(6, 0, [c.id for c in categs.values()])]

env.cr.commit()
print(f"Productos creados: {created}, actualizados: {updated}")
print(f"Demo borrados: {deleted}, archivados (usados en pedidos): {archived}")
for folder, categ in categs.items():
    print(f"  {folder}: {Product.search_count([('pos_categ_ids', 'in', categ.ids), ('active', '=', True)])} productos")
print("Categorías PdV:", ", ".join(PosCateg.search([]).mapped("name")))

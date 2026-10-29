{
    "name": "PdV - Comandas por el navegador",
    "summary": "Imprime las comandas de cocina con el diálogo de impresión del navegador",
    "description": """
Agrega el tipo "Imprimir por el navegador" a las impresoras de pedidos
(Punto de venta -> Configuración -> Impresoras de preparación). No modifica el código
de Odoo:

* El PdV trata esa impresora como cualquier impresora de cocina: aparece el botón
  "Enviar", solo se imprime lo nuevo (o lo cancelado) y cada impresora recibe solo
  sus categorías.
* En lugar de enviar la comanda a una Epson ePOS o a una caja IoT, abre el diálogo de
  impresión del dispositivo, así que sirve con cualquier impresora instalada
  (p. ej. una de tinta de oficina) o con "Guardar como PDF".

Pensado para pruebas o locales pequeños mientras no haya una térmica Epson ePOS:
hay que confirmar cada impresión y se imprime desde el dispositivo que envía.
""",
    "version": "19.0.1.0.0",
    "category": "Sales/Point of Sale",
    "author": "Punto de venta restaurantes",
    "license": "LGPL-3",
    "depends": ["point_of_sale"],
    "data": [
        "views/pos_printer_views.xml",
    ],
    "assets": {
        "point_of_sale._assets_pos": [
            "pos_comanda_navegador/static/src/**/*",
        ],
    },
    "installable": True,
    "application": False,
}

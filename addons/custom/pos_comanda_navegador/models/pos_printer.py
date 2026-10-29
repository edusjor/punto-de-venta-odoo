from odoo import fields, models


class PosPrinter(models.Model):
    _inherit = "pos.printer"

    printer_type = fields.Selection(
        selection_add=[("browser", "Imprimir por el navegador (cualquier impresora)")],
        ondelete={"browser": "set default"},
    )

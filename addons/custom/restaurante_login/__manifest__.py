{
    "name": "Restaurante - Pantalla de inicio de sesión",
    "summary": "Simplifica el login: sin registro libre, llave de acceso ni enlaces de Odoo",
    "description": """
Hereda las plantillas del login (no modifica el código de Odoo):

* Etiqueta el campo de acceso como "Correo electrónico o usuario".
* Quita el pie con "Gestionar bases de datos" y "Con la tecnología de Odoo".
* Quita el botón "Usa una llave de acceso" (passkey).
* Desactiva el registro libre ("¿No tienes una cuenta?"): las cuentas solo
  las crea un administrador.

Se mantiene "Restablecer contraseña".
""",
    "version": "19.0.1.1.0",
    "category": "Hidden",
    "author": "Punto de venta restaurantes",
    "license": "LGPL-3",
    "depends": ["web", "auth_signup", "auth_passkey"],
    "data": [
        "data/config_data.xml",
        "views/login_templates.xml",
    ],
    "installable": True,
    "application": False,
}

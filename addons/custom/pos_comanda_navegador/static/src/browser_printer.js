import { BasePrinter } from "@point_of_sale/app/utils/printer/base_printer";
import { waitImages } from "@point_of_sale/utils";

// Tiempo máximo de espera a "afterprint" (en algunos navegadores móviles
// window.print() no bloquea y el evento puede no llegar).
const AFTER_PRINT_TIMEOUT = 3000;

/**
 * Impresora de pedidos que usa el diálogo de impresión del navegador.
 * Reutiliza el mismo mecanismo que los recibos sin impresora (render-container +
 * window.print), así que aplica los estilos de impresión de ticket del PdV.
 */
export class BrowserPrinter extends BasePrinter {
    setup({ renderer }) {
        super.setup(...arguments);
        this.renderer = renderer;
    }

    async printReceipt(receipt) {
        await this.renderer.whenMounted({
            el: receipt,
            callback: async (el) => {
                await waitImages(el);
                // Esperar a que termine la impresión antes de que la siguiente comanda
                // reemplace el contenido del contenedor.
                await new Promise((resolve) => {
                    const done = () => {
                        window.removeEventListener("afterprint", done);
                        resolve();
                    };
                    window.addEventListener("afterprint", done);
                    setTimeout(done, AFTER_PRINT_TIMEOUT);
                    window.print();
                });
            },
        });
        return { successful: true };
    }

    openCashbox() {
        return { result: false };
    }
}

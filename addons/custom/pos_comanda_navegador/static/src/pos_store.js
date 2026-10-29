import { patch } from "@web/core/utils/patch";
import { PosStore } from "@point_of_sale/app/services/pos_store";
import { BrowserPrinter } from "./browser_printer";

patch(PosStore.prototype, {
    createPrinter(config) {
        if (config.printer_type === "browser") {
            return new BrowserPrinter({ renderer: this.printer.renderer });
        }
        return super.createPrinter(...arguments);
    },
});

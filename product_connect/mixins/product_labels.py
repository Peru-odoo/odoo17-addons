from odoo import models


class ProductLabelsMixin(models.AbstractModel):
    _name = "product.labels.mixin"
    _description = "Product Labels Mixin"

    bin = None
    default_code = None
    mpn = None
    condition = None
    quantity = None
    name = None

    def print_bin_labels(self) -> None:
        unique_bins = list(set(self.mapped("bin")))
        unique_bins = [bin_location for bin_location in unique_bins if bin_location]
        unique_bins.sort()
        for product_bin in unique_bins:
            if not product_bin:
                continue
            if product_bin.strip().lower() in ["", " ", "back"]:
                continue
            label_data = ["", "Bin: ", product_bin]
            label = self.env["printnode.interface"].generate_label(
                label_data, barcode=product_bin
            )
            self.env["printnode.interface"].print_label(label)

    def print_product_labels(self, print_quantity: bool = False) -> None:
        labels = []
        for record in self:
            label_data = [
                f"SKU: {record.default_code}",
                "MPN: ",
                f"(SM){record.mpn}",
                f"Bin: {record.bin or '       '}",
                record.condition.title() if record.condition else "",
            ]
            quantity = record.quantity if print_quantity and record.quantity > 0 else 1
            label = record.env["printnode.interface"].generate_label(
                label_data,
                bottom_text=self.wrap_text(record.name, 50),
                barcode=record.default_code,
                quantity=quantity,
            )
            labels.append(label)
        combined_label_base64 = self.env["printnode.interface"].combine_labels(labels)
        self.env["printnode.interface"].print_label(combined_label_base64)

    @staticmethod
    def wrap_text(text: str, max_line_length: int) -> list[str]:
        words = text.split(" ")
        lines = []
        current_line = []

        for word in words:
            if len(" ".join(current_line + [word])) > max_line_length:
                lines.append(" ".join(current_line))
                current_line = [word]
            else:
                current_line.append(word)

        if current_line:
            lines.append(" ".join(current_line))

        return lines

import os

file_path = r'c:\projects\inventory_management\lib\features\admin\admin_dashboard_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_dialog = r'''  void _showRefundConfirmDialog(Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Refund"),
        content: Text("Are you sure you want to refund the sale of ${s['itemName']}? This will restore stock and record a refund transaction."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              LoadingOverlay.show(context);
              try {
                // Actual logic for Phase 1 restoration
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund processed successfully"), backgroundColor: AppColors.success));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.danger));
              } finally {
                LoadingOverlay.hide(context);
              }
            },
            child: const Text("Confirm Refund"),
          ),
        ],
      ),
    );
  }'''

new_dialog = r'''  void _showRefundConfirmDialog(Map<String, dynamic> s) {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;
    final double maxRefundable = (s['quantity'] ?? 0.0).toDouble() - (s['refundedQuantity'] ?? 0.0).toDouble();
    double refundQty = maxRefundable;
    TextEditingController qtyC = TextEditingController(text: refundQty.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Confirm Refund"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Item: ${s['itemName']}"),
                Text("Total Sold: ${s['quantity']} | Already Refunded: ${s['refundedQuantity'] ?? 0.0}"),
                Text("Available to Refund: $maxRefundable", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 16),
                const Text("Refund Quantity:"),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) {
                    setState(() {
                      refundQty = double.tryParse(v) ?? 0.0;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: (refundQty > 0 && refundQty <= maxRefundable) ? () async {
                  Navigator.pop(ctx);
                  LoadingOverlay.show(context);
                  try {
                    await _repo.processRefund(user, s, refundQty);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund processed successfully"), backgroundColor: AppColors.success));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.danger));
                  } finally {
                    LoadingOverlay.hide(context);
                  }
                } : null,
                child: const Text("Confirm Refund"),
              ),
            ],
          );
        }
      ),
    );
  }'''

content = content.replace(old_dialog, new_dialog)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

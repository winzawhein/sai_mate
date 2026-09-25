import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/shop_models.dart';
import 'shop_controller.dart';
import 'form_chrome.dart';

const _green = Color(0xFFA5EF55);

Future<void> showProductManagement(BuildContext context, Product product) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductManagementSheet(product: product),
    );
Future<void> showCustomerManagement(BuildContext context, Customer customer) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomerManagementSheet(customer: customer),
    );

class ProductManagementSheet extends ConsumerStatefulWidget {
  const ProductManagementSheet({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<ProductManagementSheet> createState() =>
      _ProductManagementSheetState();
}

class _ProductManagementSheetState
    extends ConsumerState<ProductManagementSheet> {
  late final name = TextEditingController(text: widget.product.name);
  late final sku = TextEditingController(text: widget.product.sku);
  late final cost = TextEditingController(text: '${widget.product.costPrice}');
  late final price = TextEditingController(text: '${widget.product.salePrice}');
  late final low = TextEditingController(
    text: '${widget.product.lowStockLimit}',
  );
  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    cost.dispose();
    price.dispose();
    low.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementForm(
    title: 'ပစ္စည်းပြင်ဆင်ရန်',
    fields: [
      ManagementField(controller: name, label: 'ပစ္စည်းအမည်'),
      ManagementField(controller: sku, label: 'SKU'),
      ManagementField(controller: cost, label: 'ဝယ်စျေး', numeric: true),
      ManagementField(controller: price, label: 'ရောင်းစျေး', numeric: true),
      ManagementField(
        controller: low,
        label: 'လက်ကျန်သတိပေးပမာဏ',
        numeric: true,
      ),
    ],
    onSave: () async {
      await ref
          .read(shopProvider.notifier)
          .updateProduct(
            widget.product.copyWith(
              name: name.text.trim(),
              sku: sku.text.trim(),
              costPrice: int.tryParse(cost.text) ?? 0,
              salePrice: int.tryParse(price.text) ?? 0,
              lowStockLimit: int.tryParse(low.text) ?? 5,
            ),
          );
      if (context.mounted) Navigator.pop(context);
    },
    onDelete: () async {
      await ref.read(shopProvider.notifier).deleteProduct(widget.product);
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class CustomerManagementSheet extends ConsumerStatefulWidget {
  const CustomerManagementSheet({super.key, required this.customer});
  final Customer customer;
  @override
  ConsumerState<CustomerManagementSheet> createState() =>
      _CustomerManagementSheetState();
}

class _CustomerManagementSheetState
    extends ConsumerState<CustomerManagementSheet> {
  late final name = TextEditingController(text: widget.customer.name);
  late final phone = TextEditingController(text: widget.customer.phone);
  late final address = TextEditingController(text: widget.customer.address);
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementForm(
    title: 'ဖောက်သည်ပြင်ဆင်ရန်',
    fields: [
      ManagementField(controller: name, label: 'အမည်'),
      ManagementField(controller: phone, label: 'ဖုန်း'),
      ManagementField(controller: address, label: 'လိပ်စာ'),
    ],
    onSave: () async {
      await ref
          .read(shopProvider.notifier)
          .updateCustomer(
            widget.customer.copyWith(
              name: name.text.trim(),
              phone: phone.text.trim(),
              address: address.text.trim(),
            ),
          );
      if (context.mounted) Navigator.pop(context);
    },
    onDelete: () async {
      await ref.read(shopProvider.notifier).deleteCustomer(widget.customer);
      if (context.mounted) Navigator.pop(context);
    },
  );
}

class ManagementForm extends StatelessWidget {
  const ManagementForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    required this.onDelete,
  });
  final String title;
  final List<Widget> fields;
  final Future<void> Function() onSave, onDelete;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        22,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormHeading(title: title, icon: Icons.edit_outlined),
            const SizedBox(height: 10),
            ...fields,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: onSave,
                child: const Text('ပြင်ဆင်သိမ်းမည်'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _confirmDelete(context),
                child: const Text(
                  'ဖျက်မည်',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ဖျက်ရန်သေချာပါသလား'),
        content: const Text(
          'မှတ်တမ်းဟောင်းများအတွက် အချက်အလက်ကို လုံခြုံစွာ သိမ်းထားပါမည်။',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('မဖျက်ပါ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ဖျက်မည်'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete();
  }
}

class ManagementField extends StatelessWidget {
  const ManagementField({
    super.key,
    required this.controller,
    required this.label,
    this.numeric = false,
  });
  final TextEditingController controller;
  final String label;
  final bool numeric;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

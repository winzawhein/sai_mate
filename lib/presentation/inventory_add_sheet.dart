import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';
import 'shop_controller.dart';

const _green = Color(0xFFA5EF55);

final inventoryChooserSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

class InventoryAddChoice {
  const InventoryAddChoice.newProduct() : product = null;
  const InventoryAddChoice.existing(this.product);
  final Product? product;
  bool get createsNewProduct => product == null;
}

Future<void> showInventoryAddSheet(
  BuildContext context, {
  required VoidCallback onCreateNew,
}) async {
  final choice = await showModalBottomSheet<InventoryAddChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InventoryAddSheet(onCreateNew: onCreateNew),
  );
  if (choice == null || !context.mounted) return;
  if (choice.createsNewProduct) {
    onCreateNew();
  } else {
    await showExistingStockSheet(context, choice.product!);
  }
}

class InventoryAddSheet extends ConsumerWidget {
  const InventoryAddSheet({super.key, required this.onCreateNew});
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref
        .watch(inventoryChooserSearchProvider)
        .trim()
        .toLowerCase();
    final products = ref
        .watch(productsProvider)
        .where(
          (product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query),
        )
        .toList();
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .86,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ပစ္စည်း ထည့်ရန်',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'ရှိပြီးသားပစ္စည်း သို့မဟုတ် အသစ်ရွေးပါ',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Material(
                color: Colors.transparent,
                elevation: 5,
                shadowColor: const Color(0x401C6D5B),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: const BoxDecoration(color: Color(0xFFA5EF55)),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(
                        context,
                        const InventoryAddChoice.newProduct(),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: Color(0x33FFFFFF),
                            child: Icon(
                              Icons.add_box_rounded,
                              color: Color(0xFF18212B),
                              size: 25,
                            ),
                          ),
                          SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ပစ္စည်းအသစ် ဖန်တီးမည်',
                                  style: TextStyle(
                                    color: Color(0xFF18212B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'စာရင်းထဲတွင် မရှိသေးသောပစ္စည်း',
                                  style: TextStyle(
                                    color: Color(0xFF34402C),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF18212B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: TextField(
                onChanged: (value) =>
                    ref.read(inventoryChooserSearchProvider.notifier).state =
                        value,
                decoration: const InputDecoration(
                  hintText: 'ရှိပြီးသား ပစ္စည်းအမည် သို့မဟုတ် SKU ရှာရန်',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Text(
                'ရှိပြီးသားပစ္စည်းကို လက်ကျန်ထည့်ရန်',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('ပစ္စည်းမတွေ့ပါ'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          ExistingProductTile(product: products[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExistingProductTile extends StatelessWidget {
  const ExistingProductTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      onTap: () {
        Navigator.pop(context, InventoryAddChoice.existing(product));
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFFFFE7D6),
          borderRadius: BorderRadius.all(Radius.circular(13)),
        ),
        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFC96C36)),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${product.sku} · ${product.stock} ခု ကျန်'),
      trailing: const Icon(Icons.add_circle_rounded, color: _green),
    ),
  );
}

Future<void> showExistingStockSheet(BuildContext context, Product product) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExistingStockSheet(product: product),
    );

class ExistingStockSheet extends ConsumerStatefulWidget {
  const ExistingStockSheet({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<ExistingStockSheet> createState() => _ExistingStockSheetState();
}

class _ExistingStockSheetState extends ConsumerState<ExistingStockSheet> {
  final quantity = TextEditingController();
  late final cost = TextEditingController(text: '${widget.product.costPrice}');
  @override
  void dispose() {
    quantity.dispose();
    cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      22,
      18,
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product.name,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        Text('လက်ရှိ ${widget.product.stock} ခု ကျန်'),
        const SizedBox(height: 14),
        TextField(
          controller: quantity,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ထည့်မည့်အရေအတွက်'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'တစ်ခုဝယ်စျေး'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.all(15),
            ),
            onPressed: _save,
            child: const Text('လက်ကျန်ထည့်မည်'),
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = int.tryParse(quantity.text) ?? 0;
    if (count <= 0) return;
    final product = widget.product.copyWith(
      costPrice: int.tryParse(cost.text) ?? widget.product.costPrice,
    );
    await ref
        .read(shopProvider.notifier)
        .checkoutPurchase(
          items: [CartLine(product: product, quantity: count)],
        );
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${widget.product.name} +$count ခု ထည့်ပြီးပါပြီ · ${NumberFormat('#,##0').format(product.costPrice * count)} Ks',
        ),
        backgroundColor: _green,
      ),
    );
  }
}

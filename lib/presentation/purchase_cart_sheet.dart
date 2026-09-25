import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';
import 'shop_controller.dart';
import 'form_chrome.dart';

const _green = Color(0xFFA5EF55);

class PurchaseCartController extends StateNotifier<List<CartLine>> {
  PurchaseCartController() : super(const []);
  void add(Product product) {
    final current = state
        .where((line) => line.product.id == product.id)
        .firstOrNull;
    state = current == null
        ? [...state, CartLine(product: product, quantity: 1)]
        : [
            for (final line in state)
              if (line.product.id == product.id)
                line.copyWith(quantity: line.quantity + 1)
              else
                line,
          ];
  }

  void change(String id, int quantity) {
    state = quantity <= 0
        ? state.where((line) => line.product.id != id).toList()
        : [
            for (final line in state)
              if (line.product.id == id)
                line.copyWith(quantity: quantity)
              else
                line,
          ];
  }

  void changeCost(String id, int cost) {
    if (cost < 0) return;
    state = [
      for (final line in state)
        if (line.product.id == id)
          CartLine(
            product: line.product.copyWith(costPrice: cost),
            quantity: line.quantity,
          )
        else
          line,
    ];
  }
}

final purchaseCartProvider =
    StateNotifierProvider.autoDispose<PurchaseCartController, List<CartLine>>(
      (ref) => PurchaseCartController(),
    );
final selectedSupplierProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

class PurchaseCartSheet extends ConsumerWidget {
  const PurchaseCartSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider).valueOrNull;
    final cart = ref.watch(purchaseCartProvider);
    final products = <String, Product>{
      for (final p in shop?.products ?? const <Product>[]) p.id: p,
    };
    final revision = cart
        .map((line) => '${line.product.id}:${line.quantity}')
        .join('|');
    final total = cart.fold<int>(
      0,
      (sum, line) => sum + line.product.costPrice * line.quantity,
    );
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 12, 0),
                child: FormHeading(
                  title: 'အဝယ် Cart',
                  icon: Icons.inventory_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(revision),
                  initialValue: null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ဝယ်မည့်ပစ္စည်း ထည့်ရန်',
                  ),
                  items: products.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} · ${NumberFormat('#,##0').format(p.costPrice)} Ks',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    final product = products[id];
                    if (product != null) {
                      ref.read(purchaseCartProvider.notifier).add(product);
                    }
                  },
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text(
                          'ဝယ်မည့်ပစ္စည်း ထည့်ပါ',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: cart.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) =>
                            PurchaseLineTile(line: cart[index]),
                      ),
              ),
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: ref.watch(
                                  selectedSupplierProvider,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'ပစ္စည်းပေးသွင်းသူ',
                                ),
                                items: (shop?.suppliers ?? const <Supplier>[])
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) =>
                                    ref
                                            .read(
                                              selectedSupplierProvider.notifier,
                                            )
                                            .state =
                                        id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'ပေးသွင်းသူအသစ် ထည့်ရန်',
                              onPressed: () => _addSupplier(context, ref),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'စုစုပေါင်း',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${NumberFormat('#,##0').format(total)} Ks',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              padding: const EdgeInsets.all(15),
                            ),
                            onPressed: cart.isEmpty
                                ? null
                                : () => _checkout(context, ref, cart),
                            child: const Text('အဝယ်အတည်ပြုမည်'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(
    BuildContext context,
    WidgetRef ref,
    List<CartLine> cart,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(shopProvider.notifier)
          .checkoutPurchase(
            items: cart,
            supplierId: ref.read(selectedSupplierProvider),
          );
      if (!context.mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('အဝယ်ပြီးမြောက်ပါပြီ ✓'),
          backgroundColor: _green,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _addSupplier(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ပေးသွင်းသူအသစ်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'အမည်'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ဖုန်းနံပါတ်'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('မလုပ်တော့ပါ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ထည့်မည်'),
          ),
        ],
      ),
    );
    try {
      if (submitted != true || name.text.trim().isEmpty) return;
      await ref
          .read(shopProvider.notifier)
          .addSupplier(name.text.trim(), phone.text.trim());
      final suppliers = ref.read(shopProvider).valueOrNull?.suppliers;
      if (suppliers != null && suppliers.isNotEmpty) {
        ref.read(selectedSupplierProvider.notifier).state = suppliers.last.id;
      }
    } finally {
      name.dispose();
      phone.dispose();
    }
  }
}

class PurchaseLineTile extends ConsumerWidget {
  const PurchaseLineTile({super.key, required this.line});
  final CartLine line;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${NumberFormat('#,##0').format(line.product.costPrice * line.quantity)} Ks',
                  style: const TextStyle(color: _green),
                ),
                TextButton.icon(
                  onPressed: () => _editCost(context, ref),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text(
                    'တစ်ခု ${NumberFormat('#,##0').format(line.product.costPrice)} Ks',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref
                .read(purchaseCartProvider.notifier)
                .change(line.product.id, line.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${line.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: () => ref
                .read(purchaseCartProvider.notifier)
                .change(line.product.id, line.quantity + 1),
            icon: const Icon(Icons.add_circle, color: _green),
          ),
        ],
      ),
    ),
  );

  Future<void> _editCost(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: line.product.costPrice.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${line.product.name} ဝယ်ဈေး'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'Ks '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('မလုပ်တော့ပါ'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('သတ်မှတ်မည်'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value < 0) return;
    ref.read(purchaseCartProvider.notifier).changeCost(line.product.id, value);
  }
}

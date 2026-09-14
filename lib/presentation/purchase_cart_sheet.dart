import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';
import 'shop_controller.dart';

const _green = Color(0xFF1C6D5B);
const _cream = Color(0xFFF7F7F2);

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
          decoration: const BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.inventory_rounded, color: _green),
                    SizedBox(width: 10),
                    Text(
                      'အဝယ် Cart',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: ref.watch(selectedSupplierProvider),
                      decoration: const InputDecoration(
                        labelText: 'ပစ္စည်းပေးသွင်းသူ (မဖြစ်မနေမဟုတ်)',
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
                          ref.read(selectedSupplierProvider.notifier).state =
                              id,
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
}

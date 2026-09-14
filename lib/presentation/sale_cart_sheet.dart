import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';
import 'shop_controller.dart';

const _green = Color(0xFF1C6D5B);
const _ink = Color(0xFF18212B);

class SaleCartController extends StateNotifier<List<CartLine>> {
  SaleCartController() : super(const []);
  void add(Product product) {
    final index = state.indexWhere((line) => line.product.id == product.id);
    if (index < 0) {
      state = [...state, CartLine(product: product, quantity: 1)];
    } else {
      change(product.id, state[index].quantity + 1);
    }
  }

  void change(String productId, int quantity) {
    if (quantity <= 0) {
      state = state.where((line) => line.product.id != productId).toList();
      return;
    }
    state = [
      for (final line in state)
        if (line.product.id == productId)
          line.copyWith(quantity: quantity.clamp(1, line.product.stock))
        else
          line,
    ];
  }
}

final saleCartProvider =
    StateNotifierProvider.autoDispose<SaleCartController, List<CartLine>>(
      (ref) => SaleCartController(),
    );
final saleCreditProvider = StateProvider.autoDispose<bool>((ref) => false);
final saleCustomerProvider = StateProvider.autoDispose<String?>((ref) => null);
final saleDiscountProvider = StateProvider.autoDispose<int>((ref) => 0);

class SaleCartSheet extends ConsumerWidget {
  const SaleCartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider).valueOrNull;
    final cart = ref.watch(saleCartProvider);
    final credit = ref.watch(saleCreditProvider);
    final discount = ref.watch(saleDiscountProvider);
    final subtotal = cart.fold<int>(0, (sum, line) => sum + line.total);
    final total = (subtotal - discount).clamp(0, subtotal);
    final availableProducts = <String, Product>{
      for (final product in shop?.products ?? const <Product>[])
        if (product.stock > 0) product.id: product,
    };
    final cartRevision = cart
        .map((line) => '${line.product.id}:${line.quantity}')
        .join('|');
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
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
                padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag_rounded, color: _green),
                    SizedBox(width: 10),
                    Text(
                      'အရောင်း Cart',
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
                  key: ValueKey(cartRevision),
                  initialValue: null,
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(
                    labelText: 'ပစ္စည်းထည့်ရန်',
                  ),
                  items: availableProducts.values
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.name} · ${product.stock} ကျန်',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (productId) {
                    final product = availableProducts[productId];
                    if (product != null) {
                      ref.read(saleCartProvider.notifier).add(product);
                    }
                  },
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Text(
                          'ရောင်းမည့်ပစ္စည်း ထည့်ပါ',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: cart.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            CartLineTile(line: cart[index]),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    if (credit)
                      DropdownButtonFormField<String>(
                        initialValue: ref.watch(saleCustomerProvider),
                        decoration: const InputDecoration(
                          labelText: 'အကြွေးယူသည့် ဖောက်သည်',
                        ),
                        items: (shop?.customers ?? const <Customer>[])
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            ref.read(saleCustomerProvider.notifier).state =
                                value,
                      ),
                    Row(
                      children: [
                        const Expanded(child: Text('အကြွေးဖြင့် ရောင်းမည်')),
                        Switch(
                          value: credit,
                          onChanged: (value) =>
                              ref.read(saleCreditProvider.notifier).state =
                                  value,
                        ),
                      ],
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'လျှော့စျေး',
                        prefixText: 'Ks ',
                      ),
                      onChanged: (value) =>
                          ref.read(saleDiscountProvider.notifier).state =
                              int.tryParse(value) ?? 0,
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
                            color: _ink,
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
                            : () => _checkout(
                                context,
                                ref,
                                cart,
                                credit,
                                discount,
                              ),
                        child: const Text('အရောင်းအတည်ပြုမည်'),
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
    bool credit,
    int discount,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final customer = ref.read(saleCustomerProvider);
      if (credit && customer == null) {
        throw const FormatException('ဖောက်သည်ရွေးချယ်ပါ');
      }
      await ref
          .read(shopProvider.notifier)
          .checkoutSale(
            items: cart,
            customerId: customer,
            debt: credit,
            discount: discount,
          );
      if (!context.mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('အရောင်းပြီးမြောက်ပါပြီ ✓'),
          backgroundColor: _green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }
}

class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});
  final CartLine line;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(12),
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
                  '${NumberFormat('#,##0').format(line.total)} Ks',
                  style: const TextStyle(color: _green),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref
                .read(saleCartProvider.notifier)
                .change(line.product.id, line.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${line.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: line.quantity >= line.product.stock
                ? null
                : () => ref
                      .read(saleCartProvider.notifier)
                      .change(line.product.id, line.quantity + 1),
            icon: const Icon(Icons.add_circle, color: _green),
          ),
        ],
      ),
    ),
  );
}

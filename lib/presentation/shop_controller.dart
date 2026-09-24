import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/in_memory_shop_repository.dart';
import '../data/supabase_shop_repository.dart';
import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final repositoryProvider = Provider<ShopRepository>(
  (ref) => Supabase.instance.client.auth.currentUser == null
      ? InMemoryShopRepository()
      : SupabaseShopRepository(Supabase.instance.client),
);
final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull;
  return results == null || !results.contains(ConnectivityResult.none);
});
final shopProvider = AsyncNotifierProvider<ShopController, ShopState>(
  ShopController.new,
);
final tabProvider = StateProvider<int>((ref) => 0);
final searchProvider = StateProvider<String>((ref) => '');
final selectedProductProvider = StateProvider<String?>((ref) => null);
final selectedCustomerProvider = StateProvider<String?>((ref) => null);
final productsProvider = Provider<List<Product>>(
  (ref) => ref.watch(
    shopProvider.select((state) => state.valueOrNull?.products ?? const []),
  ),
);
final customersProvider = Provider<List<Customer>>(
  (ref) => ref.watch(
    shopProvider.select((state) => state.valueOrNull?.customers ?? const []),
  ),
);

class ShopController extends AsyncNotifier<ShopState> {
  ShopRepository get _repo => ref.read(repositoryProvider);
  @override
  Future<ShopState> build() => _repo.load();
  String _id() => const Uuid().v4();
  Future<void> _publish(ShopState next) async {
    state = AsyncData(next);
    if (_repo case OfflineCacheRepository cache) await cache.cacheState(next);
  }

  Future<void> _commit(ShopState next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> addProduct({
    required String name,
    required String sku,
    required int cost,
    required int price,
    required int stock,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final s = state.requireValue;
    final normalizedName = name.trim().toLowerCase();
    final normalizedSku = sku.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      throw const FormatException('ပစ္စည်းအမည် ထည့်ပါ');
    }
    if (s.products.any(
      (product) => product.name.trim().toLowerCase() == normalizedName,
    )) {
      throw const FormatException(
        'ဤပစ္စည်း ရှိပြီးသားဖြစ်ပါသည်။ ရှိပြီးသားပစ္စည်းကို ရွေးပြီး လက်ကျန်ထည့်ပါ။',
      );
    }
    if (normalizedSku.isNotEmpty &&
        s.products.any(
          (product) => product.sku.trim().toLowerCase() == normalizedSku,
        )) {
      throw const FormatException('ဤ SKU ကို အသုံးပြုပြီးသား ဖြစ်ပါသည်။');
    }
    final product = Product(
      id: _id(),
      name: name.trim(),
      sku: sku.trim(),
      stock: stock,
      costPrice: cost,
      salePrice: price,
      lowStockLimit: 5,
    );
    if (_repo case ProductCrudRepository crud) {
      await crud.createProduct(
        product,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
      );
      final refreshed = await _repo.load();
      final productWasLoaded = refreshed.products.any(
        (candidate) => candidate.id == product.id,
      );
      await _publish(
        productWasLoaded
            ? refreshed
            : refreshed.copyWith(products: [...refreshed.products, product]),
      );
      return;
    }
    await _commit(s.copyWith(products: [...s.products, product]));
  }

  Future<void> addCustomer(String name, String phone) async {
    final s = state.requireValue;
    final customer = Customer(id: _id(), name: name, phone: phone);
    if (_repo case CustomerDebtCrudRepository crud) {
      await crud.createCustomer(customer);
      final refreshed = await _repo.load();
      await _publish(
        refreshed.customers.any((item) => item.id == customer.id)
            ? refreshed
            : refreshed.copyWith(customers: [...refreshed.customers, customer]),
      );
      return;
    }
    await _commit(s.copyWith(customers: [...s.customers, customer]));
  }

  Future<void> updateProductImage({
    required Product product,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    if (_repo case ProductCrudRepository crud) {
      await crud.updateProductImage(
        product,
        imageBytes: imageBytes,
        imageExtension: imageExtension,
      );
      state = AsyncData(await _repo.load());
    }
  }

  Future<void> addSupplier(String name, String phone) async {
    final s = state.requireValue;
    final supplier = Supplier(id: _id(), name: name, phone: phone);
    if (_repo case CustomerDebtCrudRepository crud) {
      await crud.createSupplier(supplier);
      state = AsyncData(await _repo.load());
      return;
    }
    await _commit(s.copyWith(suppliers: [...s.suppliers, supplier]));
  }

  Future<void> addDebt({
    required String customerId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final s = state.requireValue;
    final debt = Debt(
      id: _id(),
      customerId: customerId,
      amount: amount,
      paid: 0,
      createdAt: DateTime.now(),
    );
    if (_repo case CustomerDebtCrudRepository crud) {
      await crud.createDebt(debt);
      final refreshed = await _repo.load();
      await _publish(
        refreshed.debts.any((item) => item.id == debt.id)
            ? refreshed
            : refreshed.copyWith(debts: [...refreshed.debts, debt]),
      );
      return;
    }
    await _commit(s.copyWith(debts: [...s.debts, debt]));
  }

  Future<void> sell({
    required String productId,
    required int quantity,
    String? customerId,
    bool debt = false,
  }) async {
    final before = state.requireValue;
    if (_repo case TransactionalShopRepository tx) {
      await tx.createSale(
        productId: productId,
        quantity: quantity,
        customerId: customerId,
        debt: debt,
      );
      final refreshed = await _repo.load();
      final old = before.products.firstWhere((p) => p.id == productId);
      final remote = refreshed.products.firstWhere((p) => p.id == productId);
      if (remote.stock < old.stock) {
        await _publish(refreshed);
      } else {
        final total = old.salePrice * quantity;
        await _publish(
          refreshed.copyWith(
            products: refreshed.products
                .map(
                  (p) => p.id == productId
                      ? p.copyWith(stock: old.stock - quantity)
                      : p,
                )
                .toList(),
            movements: [
              ...refreshed.movements,
              StockMovement(
                id: _id(),
                productId: productId,
                quantity: -quantity,
                type: MovementType.sale,
                total: total,
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );
      }
      return;
    }
    final s = state.requireValue;
    final p = s.products.firstWhere((e) => e.id == productId);
    if (quantity <= 0 || quantity > p.stock) {
      throw StateError('လက်ကျန်ပမာဏ မလုံလောက်ပါ');
    }
    final total = p.salePrice * quantity;
    final ps = s.products
        .map((e) => e.id == p.id ? e.copyWith(stock: e.stock - quantity) : e)
        .toList();
    final movement = StockMovement(
      id: _id(),
      productId: p.id,
      quantity: -quantity,
      type: MovementType.sale,
      total: total,
      createdAt: DateTime.now(),
    );
    final ds = debt && customerId != null
        ? [
            ...s.debts,
            Debt(
              id: _id(),
              customerId: customerId,
              amount: total,
              paid: 0,
              createdAt: DateTime.now(),
            ),
          ]
        : s.debts;
    await _commit(
      s.copyWith(
        products: ps,
        movements: [...s.movements, movement],
        debts: ds,
      ),
    );
  }

  Future<void> checkoutSale({
    required List<CartLine> items,
    String? customerId,
    bool debt = false,
    int discount = 0,
    String paymentMethod = 'cash',
  }) async {
    if (items.isEmpty) throw const FormatException('Cart is empty');
    if (!ref.read(isOnlineProvider)) {
      for (final line in items) {
        await sell(
          productId: line.product.id,
          quantity: line.quantity,
          customerId: customerId,
          debt: debt,
        );
      }
      return;
    }
    if (_repo case TransactionalShopRepository tx) {
      await tx.createSaleCart(
        items: items,
        customerId: customerId,
        debt: debt,
        discount: discount,
        paymentMethod: paymentMethod,
      );
      state = AsyncData(await _repo.load());
      return;
    }
    for (final line in items) {
      await sell(productId: line.product.id, quantity: line.quantity);
    }
  }

  Future<void> purchase({
    required String productId,
    required int quantity,
  }) async {
    final before = state.requireValue;
    if (_repo case TransactionalShopRepository tx) {
      await tx.createPurchase(productId: productId, quantity: quantity);
      final refreshed = await _repo.load();
      final old = before.products.firstWhere((p) => p.id == productId);
      final remote = refreshed.products.firstWhere((p) => p.id == productId);
      if (remote.stock > old.stock) {
        await _publish(refreshed);
      } else {
        await _publish(
          refreshed.copyWith(
            products: refreshed.products
                .map(
                  (p) => p.id == productId
                      ? p.copyWith(stock: old.stock + quantity)
                      : p,
                )
                .toList(),
            movements: [
              ...refreshed.movements,
              StockMovement(
                id: _id(),
                productId: productId,
                quantity: quantity,
                type: MovementType.purchase,
                total: old.costPrice * quantity,
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );
      }
      return;
    }
    final s = state.requireValue;
    final p = s.products.firstWhere((e) => e.id == productId);
    final ps = s.products
        .map((e) => e.id == p.id ? e.copyWith(stock: e.stock + quantity) : e)
        .toList();
    final m = StockMovement(
      id: _id(),
      productId: p.id,
      quantity: quantity,
      type: MovementType.purchase,
      total: p.costPrice * quantity,
      createdAt: DateTime.now(),
    );
    await _commit(s.copyWith(products: ps, movements: [...s.movements, m]));
  }

  Future<void> checkoutPurchase({
    required List<CartLine> items,
    String? supplierId,
  }) async {
    if (items.isEmpty) throw const FormatException('Cart is empty');
    if (!ref.read(isOnlineProvider)) {
      for (final line in items) {
        await purchase(productId: line.product.id, quantity: line.quantity);
      }
      return;
    }
    if (_repo case TransactionalShopRepository tx) {
      await tx.createPurchaseCart(items: items, supplierId: supplierId);
      final refreshed = await _repo.load();
      state = AsyncData(refreshed);
      return;
    }
    for (final line in items) {
      await purchase(productId: line.product.id, quantity: line.quantity);
    }
  }

  Future<void> collectPayment(String debtId, int amount) async {
    if (_repo case TransactionalShopRepository tx) {
      await tx.collectDebtPayment(debtId: debtId, amount: amount);
      state = AsyncData(await _repo.load());
      return;
    }
    final s = state.requireValue;
    final ds = s.debts
        .map(
          (d) => d.id == debtId
              ? d.copyWith(paid: (d.paid + amount).clamp(0, d.amount))
              : d,
        )
        .toList();
    await _commit(s.copyWith(debts: ds));
  }

  Future<void> updateProduct(Product product) async {
    if (_repo case RecordManagementRepository records) {
      await records.updateProduct(product);
      state = AsyncData(await _repo.load());
    }
  }

  Future<void> deleteProduct(Product product) async {
    if (_repo case RecordManagementRepository records) {
      await records.deleteProduct(product);
      state = AsyncData(await _repo.load());
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    if (_repo case RecordManagementRepository records) {
      await records.updateCustomer(customer);
      state = AsyncData(await _repo.load());
    }
  }

  Future<void> deleteCustomer(Customer customer) async {
    if (_repo case RecordManagementRepository records) {
      await records.deleteCustomer(customer);
      state = AsyncData(await _repo.load());
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
final shopProvider = AsyncNotifierProvider<ShopController, ShopState>(
  ShopController.new,
);
final tabProvider = StateProvider<int>((ref) => 0);
final searchProvider = StateProvider<String>((ref) => '');
final selectedProductProvider = StateProvider<String?>((ref) => null);
final selectedCustomerProvider = StateProvider<String?>((ref) => null);
final productsProvider = Provider<List<Product>>(
  (ref) => ref.watch(shopProvider).valueOrNull?.products ?? const [],
);
final customersProvider = Provider<List<Customer>>(
  (ref) => ref.watch(shopProvider).valueOrNull?.customers ?? const [],
);

class ShopController extends AsyncNotifier<ShopState> {
  ShopRepository get _repo => ref.read(repositoryProvider);
  @override
  Future<ShopState> build() => _repo.load();
  String _id() => const Uuid().v4();
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
  }) async {
    final s = state.requireValue;
    final product = Product(
      id: _id(),
      name: name,
      sku: sku,
      stock: stock,
      costPrice: cost,
      salePrice: price,
      lowStockLimit: 5,
    );
    if (_repo case ProductCrudRepository crud) {
      await crud.createProduct(product);
      state = AsyncData(await _repo.load());
      return;
    }
    await _commit(s.copyWith(products: [...s.products, product]));
  }

  Future<void> addCustomer(String name, String phone) async {
    final s = state.requireValue;
    final customer = Customer(id: _id(), name: name, phone: phone);
    if (_repo case CustomerDebtCrudRepository crud) {
      await crud.createCustomer(customer);
      state = AsyncData(await _repo.load());
      return;
    }
    await _commit(s.copyWith(customers: [...s.customers, customer]));
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
      state = AsyncData(await _repo.load());
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
    if (_repo case TransactionalShopRepository tx) {
      await tx.createSale(
        productId: productId,
        quantity: quantity,
        customerId: customerId,
        debt: debt,
      );
      state = AsyncData(await _repo.load());
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

  Future<void> purchase({
    required String productId,
    required int quantity,
  }) async {
    if (_repo case TransactionalShopRepository tx) {
      await tx.createPurchase(productId: productId, quantity: quantity);
      state = AsyncData(await _repo.load());
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
}

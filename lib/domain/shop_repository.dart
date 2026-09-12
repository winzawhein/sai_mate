import 'shop_models.dart';

abstract interface class ShopRepository {
  Future<ShopState> load();
  Future<void> save(ShopState state);
}

abstract interface class TransactionalShopRepository {
  Future<void> createSale({
    required String productId,
    required int quantity,
    String? customerId,
    bool debt = false,
  });
  Future<void> createPurchase({
    required String productId,
    required int quantity,
  });
  Future<void> collectDebtPayment({
    required String debtId,
    required int amount,
  });
}

abstract interface class ProductCrudRepository {
  Future<void> createProduct(Product product);
}

abstract interface class CustomerDebtCrudRepository {
  Future<void> createCustomer(Customer customer);
  Future<void> createSupplier(Supplier supplier);
  Future<void> createDebt(Debt debt);
}

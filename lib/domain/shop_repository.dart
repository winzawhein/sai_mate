import 'dart:typed_data';

import 'shop_models.dart';

abstract interface class ShopRepository {
  Future<ShopState> load();
  Future<void> save(ShopState state);
}

abstract interface class TransactionalShopRepository {
  Future<void> createSaleCart({
    required List<CartLine> items,
    String? customerId,
    bool debt = false,
    int discount = 0,
    String paymentMethod = 'cash',
  });
  Future<void> createPurchaseCart({
    required List<CartLine> items,
    String? supplierId,
  });
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
  Future<void> createProduct(
    Product product, {
    Uint8List? imageBytes,
    String? imageExtension,
  });
  Future<void> updateProductImage(
    Product product, {
    required Uint8List imageBytes,
    required String imageExtension,
  });
}

abstract interface class CustomerDebtCrudRepository {
  Future<void> createCustomer(Customer customer);
  Future<void> createSupplier(Supplier supplier);
  Future<void> createDebt(Debt debt);
}

abstract interface class RecordManagementRepository {
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(Product product);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(Customer customer);
}

abstract interface class HistoryRepository {
  Future<List<TransactionRecord>> loadTransactions();
  Future<void> returnSaleItem({
    required String saleId,
    required String productId,
    required int quantity,
  });
}

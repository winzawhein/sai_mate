import 'package:flutter_test/flutter_test.dart';
import 'package:sai_mate/domain/shop_models.dart';
import 'package:sai_mate/presentation/purchase_cart_sheet.dart';
import 'package:sai_mate/presentation/sale_cart_sheet.dart';

const product = Product(
  id: 'p1',
  name: 'Coffee',
  sku: 'COF-1',
  stock: 3,
  costPrice: 1000,
  salePrice: 1500,
  lowStockLimit: 1,
);

void main() {
  group('SaleCartController', () {
    test('combines duplicate products and respects available stock', () {
      final cart = SaleCartController();

      cart.add(product);
      cart.add(product);
      cart.change(product.id, 99);

      expect(cart.state, hasLength(1));
      expect(cart.state.single.quantity, product.stock);
      expect(cart.state.single.total, product.salePrice * product.stock);
    });

    test('removes an item when quantity reaches zero', () {
      final cart = SaleCartController()..add(product);

      cart.change(product.id, 0);

      expect(cart.state, isEmpty);
    });
  });

  group('PurchaseCartController', () {
    test('edits purchase cost without changing quantity', () {
      final cart = PurchaseCartController()..add(product);
      cart.change(product.id, 4);

      cart.changeCost(product.id, 1250);

      expect(cart.state.single.quantity, 4);
      expect(cart.state.single.product.costPrice, 1250);
    });

    test('removes an item when quantity reaches zero', () {
      final cart = PurchaseCartController()..add(product);

      cart.change(product.id, 0);

      expect(cart.state, isEmpty);
    });
  });

  test('transaction gross profit uses the captured sale cost', () {
    final record = TransactionRecord(
      id: 'sale-1',
      sale: true,
      total: 3000,
      createdAt: DateTime(2026),
      lines: const [
        TransactionLine(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 1500,
          unitCost: 1000,
        ),
      ],
    );

    expect(record.grossProfit, 1000);
  });
}

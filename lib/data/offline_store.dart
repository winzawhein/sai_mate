import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shop_models.dart';

class OfflineStore {
  const OfflineStore();
  String _snapshot(String user) => 'sai_mate.snapshot.$user';
  String _queue(String user) => 'sai_mate.queue.$user';
  String _shop(String user) => 'sai_mate.shop.$user';
  Future<void> writeShopId(String user, String shopId) async =>
      (await SharedPreferences.getInstance()).setString(_shop(user), shopId);
  Future<String?> readShopId(String user) async =>
      (await SharedPreferences.getInstance()).getString(_shop(user));
  Future<void> write(String user, ShopState state) async {
    final json = {
      'shopName': state.shopName,
      'ownerName': state.ownerName,
      'salesTotal': state.salesTotal,
      'products': state.products
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'sku': p.sku,
              'stock_quantity': p.stock,
              'cost_price': p.costPrice,
              'sale_price': p.salePrice,
              'low_stock_limit': p.lowStockLimit,
              'image_path': p.imagePath,
            },
          )
          .toList(),
      'customers': state.customers
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'phone': c.phone,
              'address': c.address,
              'balance': c.debt,
            },
          )
          .toList(),
      'suppliers': state.suppliers
          .map((s) => {'id': s.id, 'name': s.name, 'phone': s.phone})
          .toList(),
      'debts': state.debts
          .map(
            (d) => {
              'id': d.id,
              'customer_id': d.customerId,
              'amount': d.amount,
              'paid': d.paid,
              'created_at': d.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'movements': state.movements
          .map(
            (m) => {
              'id': m.id,
              'product_id': m.productId,
              'quantity': m.quantity,
              'movement_type': m.type.databaseValue,
              'created_at': m.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
    await (await SharedPreferences.getInstance()).setString(
      _snapshot(user),
      jsonEncode(json),
    );
  }

  Future<ShopState?> read(String user) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _snapshot(user),
    );
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return ShopState(
      shopName: j['shopName'] ?? 'Sai Mate',
      ownerName: j['ownerName'] ?? '',
      salesTotal: j['salesTotal'] as int?,
      products: (j['products'] as List)
          .map((e) => Product.fromJson(e))
          .toList(),
      customers: (j['customers'] as List)
          .map((e) => Customer.fromJson(e))
          .toList(),
      suppliers: (j['suppliers'] as List)
          .map((e) => Supplier.fromJson(e))
          .toList(),
      debts: (j['debts'] as List).map((e) => Debt.fromJson(e)).toList(),
      movements: (j['movements'] as List)
          .map((e) => StockMovement.fromJson(e))
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> pending(String user) async =>
      ((await SharedPreferences.getInstance()).getStringList(_queue(user)) ??
              [])
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
  Future<void> enqueue(String user, Map<String, dynamic> command) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_queue(user)) ?? [];
    list.add(jsonEncode(command));
    await prefs.setStringList(_queue(user), list);
  }

  Future<void> replaceQueue(
    String user,
    List<Map<String, dynamic>> commands,
  ) async => (await SharedPreferences.getInstance()).setStringList(
    _queue(user),
    commands.map(jsonEncode).toList(),
  );
}

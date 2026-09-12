import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

class SupabaseShopRepository
    implements
        ShopRepository,
        TransactionalShopRepository,
        ProductCrudRepository,
        CustomerDebtCrudRepository {
  SupabaseShopRepository(this.client);
  final SupabaseClient client;
  String? _shopId;

  Future<String> _shop() async {
    if (_shopId != null) return _shopId!;
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    final row = await client
        .from('shop_members')
        .select('shop_id')
        .eq('user_id', user.id)
        .limit(1)
        .single();
    return _shopId = row['shop_id'] as String;
  }

  @override
  Future<void> createProduct(Product p) async {
    await client.from('products').insert({
      'id': p.id,
      'shop_id': await _shop(),
      'name': p.name,
      'sku': p.sku.isEmpty ? null : p.sku,
      'cost_price': p.costPrice,
      'sale_price': p.salePrice,
      'stock_quantity': p.stock,
      'low_stock_limit': p.lowStockLimit,
    });
  }

  @override
  Future<void> createCustomer(Customer customer) async {
    await client.from('customers').insert({
      'id': customer.id,
      'shop_id': await _shop(),
      'name': customer.name,
      'phone': customer.phone.isEmpty ? null : customer.phone,
      'address': customer.address.isEmpty ? null : customer.address,
    });
  }

  @override
  Future<void> createSupplier(Supplier supplier) async {
    await client.from('suppliers').insert({
      'id': supplier.id,
      'shop_id': await _shop(),
      'name': supplier.name,
      'phone': supplier.phone.isEmpty ? null : supplier.phone,
    });
  }

  @override
  Future<void> createDebt(Debt debt) async {
    await client.from('debts').insert({
      'id': debt.id,
      'shop_id': await _shop(),
      'customer_id': debt.customerId,
      'amount': debt.amount,
      'paid': debt.paid,
      'created_at': debt.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> createSale({
    required String productId,
    required int quantity,
    String? customerId,
    bool debt = false,
  }) async {
    final requestId = const Uuid().v4();
    final params = {
      'p_shop_id': await _shop(),
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_customer_id': customerId,
      'p_on_credit': debt,
      'p_request_id': requestId,
    };
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await client
            .rpc('create_sale', params: params)
            .timeout(const Duration(seconds: 15));
        return;
      } catch (error, stack) {
        if (error is PostgrestException && error.code == 'PGRST202') {
          developer.log(
            'Using legacy create_sale RPC signature',
            name: 'SaiMate.Supabase',
          );
          await client.rpc(
            'create_sale',
            params: {
              'p_shop_id': params['p_shop_id'],
              'p_product_id': productId,
              'p_quantity': quantity,
              'p_customer_id': customerId,
              'p_on_credit': debt,
            },
          );
          return;
        }
        if (error is PostgrestException) {
          rethrow;
        }
        lastError = error;
        developer.log(
          'create_sale failed (attempt $attempt)',
          name: 'SaiMate.Supabase',
          error: error,
          stackTrace: stack,
        );
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    throw StateError(
      'Supabase ချိတ်ဆက်၍မရပါ။ အင်တာနက်စစ်ပြီး ထပ်ကြိုးစားပါ။ ($lastError)',
    );
  }

  @override
  Future<void> createPurchase({
    required String productId,
    required int quantity,
  }) async {
    await client.rpc(
      'create_purchase',
      params: {
        'p_shop_id': await _shop(),
        'p_product_id': productId,
        'p_quantity': quantity,
      },
    );
  }

  @override
  Future<void> collectDebtPayment({
    required String debtId,
    required int amount,
  }) async {
    await client.rpc(
      'collect_debt_payment',
      params: {
        'p_shop_id': await _shop(),
        'p_debt_id': debtId,
        'p_amount': amount,
      },
    );
  }

  @override
  Future<ShopState> load() async {
    final id = await _shop();
    final monthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    ).toUtc().toIso8601String();
    final results = await Future.wait([
      client.from('shops').select('name').eq('id', id).single(),
      client
          .from('profiles')
          .select('full_name')
          .eq('id', client.auth.currentUser!.id)
          .single(),
      client
          .from('products')
          .select('*, categories(name)')
          .eq('shop_id', id)
          .isFilter('deleted_at', null)
          .order('name'),
      client.from('customer_balances').select().eq('shop_id', id).order('name'),
      client
          .from('suppliers')
          .select()
          .eq('shop_id', id)
          .isFilter('deleted_at', null)
          .order('name'),
      client.from('debts').select().eq('shop_id', id).order('created_at'),
      client
          .from('stock_movements')
          .select()
          .eq('shop_id', id)
          .order('created_at'),
      client
          .from('sales')
          .select('total')
          .eq('shop_id', id)
          .gte('created_at', monthStart),
    ]);
    final shopRow = results[0] as Map<String, dynamic>;
    final profileRow = results[1] as Map<String, dynamic>;
    return ShopState(
      shopName: shopRow['name'] as String? ?? 'Sai Mate',
      ownerName: profileRow['full_name'] as String? ?? '',
      products: (results[2] as List).map((e) => Product.fromJson(e)).toList(),
      customers: (results[3] as List).map((e) => Customer.fromJson(e)).toList(),
      suppliers: (results[4] as List).map((e) => Supplier.fromJson(e)).toList(),
      debts: (results[5] as List).map((e) => Debt.fromJson(e)).toList(),
      movements: (results[6] as List)
          .map((e) => StockMovement.fromJson(e))
          .toList(),
      salesTotal: (results[7] as List).fold<int>(
        0,
        (sum, e) => sum + ((e['total'] as num).toInt()),
      ),
    );
  }

  @override
  Future<void> save(ShopState state) async {
    final id = await _shop();
    if (state.products.isNotEmpty) {
      await client
          .from('products')
          .upsert(
            state.products
                .map(
                  (p) => {
                    'id': p.id,
                    'shop_id': id,
                    'name': p.name,
                    'sku': p.sku,
                    'cost_price': p.costPrice,
                    'sale_price': p.salePrice,
                    'stock_quantity': p.stock,
                    'low_stock_limit': p.lowStockLimit,
                  },
                )
                .toList(),
          );
    }
    if (state.customers.isNotEmpty) {
      await client
          .from('customers')
          .upsert(
            state.customers
                .map(
                  (c) => {
                    'id': c.id,
                    'shop_id': id,
                    'name': c.name,
                    'phone': c.phone,
                    'address': c.address,
                  },
                )
                .toList(),
          );
    }
    if (state.suppliers.isNotEmpty) {
      await client
          .from('suppliers')
          .upsert(
            state.suppliers
                .map(
                  (s) => {
                    'id': s.id,
                    'shop_id': id,
                    'name': s.name,
                    'phone': s.phone,
                  },
                )
                .toList(),
          );
    }
    if (state.debts.isNotEmpty) {
      await client
          .from('debts')
          .upsert(
            state.debts
                .map(
                  (d) => {
                    'id': d.id,
                    'shop_id': id,
                    'customer_id': d.customerId,
                    'amount': d.amount,
                    'paid': d.paid,
                    'created_at': d.createdAt.toIso8601String(),
                  },
                )
                .toList(),
          );
    }
    if (state.movements.isNotEmpty) {
      await client
          .from('stock_movements')
          .upsert(
            state.movements
                .map(
                  (m) => {
                    'id': m.id,
                    'shop_id': id,
                    'product_id': m.productId,
                    'movement_type': m.type.name,
                    'quantity': m.quantity,
                    'created_at': m.createdAt.toIso8601String(),
                  },
                )
                .toList(),
          );
    }
  }
}

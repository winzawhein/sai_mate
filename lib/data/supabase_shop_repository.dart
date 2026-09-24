import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';
import 'offline_store.dart';

class SupabaseShopRepository
    implements
        ShopRepository,
        OfflineCacheRepository,
        TransactionalShopRepository,
        ProductCrudRepository,
        CustomerDebtCrudRepository,
        RecordManagementRepository,
        HistoryRepository {
  SupabaseShopRepository(this.client);
  final SupabaseClient client;
  String? _shopId;
  final OfflineStore _offline = const OfflineStore();

  @override
  Future<void> cacheState(ShopState state) async {
    final user = client.auth.currentUser;
    if (user != null) await _offline.write(user.id, state);
  }

  Future<String> _shop() async {
    if (_shopId != null) return _shopId!;
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    try {
      final row = await client
          .from('shop_members')
          .select('shop_id')
          .eq('user_id', user.id)
          .limit(1)
          .single();
      _shopId = row['shop_id'] as String;
      await _offline.writeShopId(user.id, _shopId!);
      return _shopId!;
    } catch (error) {
      if (error is PostgrestException) rethrow;
      final cached = await _offline.readShopId(user.id);
      if (cached != null) return _shopId = cached;
      rethrow;
    }
  }

  @override
  Future<void> createProduct(
    Product p, {
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final shopId = await _shop();
    String? imagePath;
    if (imageBytes != null) {
      final extension = _safeImageExtension(imageExtension);
      imagePath = '$shopId/${p.id}.$extension';
      await client.storage
          .from('product-images')
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
              upsert: false,
            ),
          );
    }
    final values = <String, dynamic>{
      'id': p.id,
      'shop_id': shopId,
      'name': p.name,
      'sku': p.sku.isEmpty ? null : p.sku,
      'cost_price': p.costPrice,
      'sale_price': p.salePrice,
      'stock_quantity': p.stock,
      'low_stock_limit': p.lowStockLimit,
      'image_path': imagePath,
    };
    try {
      await client.from('products').insert(values);
    } catch (error) {
      if (imagePath != null) {
        await client.storage.from('product-images').remove([imagePath]);
      }
      if (error is! PostgrestException && imageBytes == null) {
        await _offline.enqueue(client.auth.currentUser!.id, {
          'kind': 'insert',
          'table': 'products',
          'values': values,
        });
        return;
      }
      rethrow;
    }
  }

  String _safeImageExtension(String? value) {
    final extension = value?.toLowerCase().replaceAll('.', '');
    return extension == 'png' ? 'png' : 'jpg';
  }

  @override
  Future<void> updateProductImage(
    Product product, {
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    final shopId = await _shop();
    final extension = _safeImageExtension(imageExtension);
    final imagePath = '$shopId/${product.id}.$extension';
    await client.storage
        .from('product-images')
        .uploadBinary(
          imagePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    await client
        .from('products')
        .update({'image_path': imagePath})
        .eq('id', product.id)
        .eq('shop_id', shopId);
    if (product.imagePath != null && product.imagePath != imagePath) {
      await client.storage.from('product-images').remove([product.imagePath!]);
    }
  }

  @override
  Future<void> createCustomer(Customer customer) async {
    final values = {
      'id': customer.id,
      'shop_id': await _shop(),
      'name': customer.name,
      'phone': customer.phone.isEmpty ? null : customer.phone,
      'address': customer.address.isEmpty ? null : customer.address,
    };
    try {
      await client.from('customers').insert(values);
    } catch (error) {
      if (error is PostgrestException) rethrow;
      await _offline.enqueue(client.auth.currentUser!.id, {
        'kind': 'insert',
        'table': 'customers',
        'values': values,
      });
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    await client
        .from('products')
        .update({
          'name': product.name,
          'sku': product.sku.isEmpty ? null : product.sku,
          'cost_price': product.costPrice,
          'sale_price': product.salePrice,
          'low_stock_limit': product.lowStockLimit,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', product.id)
        .eq('shop_id', await _shop());
  }

  @override
  Future<void> deleteProduct(Product product) async {
    await client
        .from('products')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', product.id)
        .eq('shop_id', await _shop());
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    await client
        .from('customers')
        .update({
          'name': customer.name,
          'phone': customer.phone.isEmpty ? null : customer.phone,
          'address': customer.address.isEmpty ? null : customer.address,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', customer.id)
        .eq('shop_id', await _shop());
  }

  @override
  Future<void> deleteCustomer(Customer customer) async {
    if (customer.debt > 0) {
      throw StateError('အကြွေးကျန်ရှိသော ဖောက်သည်ကို ဖျက်၍မရပါ');
    }
    await client
        .from('customers')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', customer.id)
        .eq('shop_id', await _shop());
  }

  @override
  Future<List<TransactionRecord>> loadTransactions() async {
    final shopId = await _shop();
    final results = await Future.wait([
      _loadSalesHistory(shopId),
      client
          .from('purchases')
          .select(
            'id,total,created_at,suppliers(name),purchase_items(product_id,quantity,unit_cost,products(name))',
          )
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100),
    ]);
    final sales = (results[0] as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      return TransactionRecord(
        id: row['id'],
        sale: true,
        total: (row['total'] as num).toInt(),
        createdAt: DateTime.parse(row['created_at']),
        partyName: (row['customers'] as Map?)?['name'] as String?,
        lines: (row['sale_items'] as List).map((rawLine) {
          final line = rawLine as Map<String, dynamic>;
          return TransactionLine(
            productId: line['product_id'],
            name: (line['products'] as Map?)?['name'] as String? ?? 'Product',
            quantity: (line['quantity'] as num).toInt(),
            unitPrice: (line['unit_price'] as num).toInt(),
            unitCost:
                (line['cost_basis'] as num?)?.toInt() ??
                ((line['products'] as Map?)?['cost_price'] as num?)?.toInt() ??
                0,
          );
        }).toList(),
      );
    });
    final purchases = (results[1] as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      return TransactionRecord(
        id: row['id'],
        sale: false,
        total: (row['total'] as num).toInt(),
        createdAt: DateTime.parse(row['created_at']),
        partyName: (row['suppliers'] as Map?)?['name'] as String?,
        lines: (row['purchase_items'] as List).map((rawLine) {
          final line = rawLine as Map<String, dynamic>;
          return TransactionLine(
            productId: line['product_id'],
            name: (line['products'] as Map?)?['name'] as String? ?? 'Product',
            quantity: (line['quantity'] as num).toInt(),
            unitPrice: (line['unit_cost'] as num).toInt(),
            unitCost: (line['unit_cost'] as num).toInt(),
          );
        }).toList(),
      );
    });
    return [...sales, ...purchases]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Map<String, dynamic>>> _loadSalesHistory(String shopId) async {
    const base =
        'id,total,created_at,customers(name),sale_items(product_id,quantity,unit_price,products(name,cost_price))';
    const withCost =
        'id,total,created_at,customers(name),sale_items(product_id,quantity,unit_price,cost_basis,products(name,cost_price))';
    try {
      return await client
          .from('sales')
          .select(withCost)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100);
    } on PostgrestException {
      // Older deployments remain usable until upgrade_v4.sql is installed.
      return client
          .from('sales')
          .select(base)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100);
    }
  }

  @override
  Future<void> returnSaleItem({
    required String saleId,
    required String productId,
    required int quantity,
  }) async {
    await client.rpc(
      'return_sale_item',
      params: {
        'p_shop_id': await _shop(),
        'p_sale_id': saleId,
        'p_product_id': productId,
        'p_quantity': quantity,
      },
    );
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
    final values = {
      'id': debt.id,
      'shop_id': await _shop(),
      'customer_id': debt.customerId,
      'amount': debt.amount,
      'paid': debt.paid,
      'created_at': debt.createdAt.toUtc().toIso8601String(),
    };
    try {
      await client.from('debts').insert(values);
    } catch (error) {
      if (error is PostgrestException) rethrow;
      await _offline.enqueue(client.auth.currentUser!.id, {
        'kind': 'insert',
        'table': 'debts',
        'values': values,
      });
    }
  }

  @override
  Future<void> createSaleCart({
    required List<CartLine> items,
    String? customerId,
    bool debt = false,
    int discount = 0,
    String paymentMethod = 'cash',
  }) async {
    final params = <String, dynamic>{
      'p_shop_id': await _shop(),
      'p_items': items
          .map(
            (line) => {
              'product_id': line.product.id,
              'quantity': line.quantity,
            },
          )
          .toList(),
      'p_customer_id': customerId,
      'p_on_credit': debt,
      'p_discount': discount,
      'p_payment_method': paymentMethod,
      'p_request_id': const Uuid().v4(),
    };
    try {
      await client.rpc('create_sale_cart', params: params);
    } catch (error) {
      if (error is PostgrestException) rethrow;
      await _offline.enqueue(client.auth.currentUser!.id, {
        'rpc': 'create_sale_cart',
        'params': params,
      });
    }
  }

  @override
  Future<void> createPurchaseCart({
    required List<CartLine> items,
    String? supplierId,
  }) async {
    // The original production schema exposes create_purchase for one product.
    // Use it for the quick stock-entry flow so the quantity is committed even
    // when the optional v2 multi-item RPC has not been installed yet.
    if (items.length == 1 && supplierId == null) {
      final line = items.single;
      await client
          .from('products')
          .update({'cost_price': line.product.costPrice})
          .eq('id', line.product.id)
          .eq('shop_id', await _shop());
      await createPurchase(productId: line.product.id, quantity: line.quantity);
      return;
    }
    final params = <String, dynamic>{
      'p_shop_id': await _shop(),
      'p_items': items
          .map(
            (line) => {
              'product_id': line.product.id,
              'quantity': line.quantity,
              'unit_cost': line.product.costPrice,
            },
          )
          .toList(),
      'p_supplier_id': supplierId,
      'p_request_id': const Uuid().v4(),
    };
    try {
      await client.rpc('create_purchase_cart', params: params);
    } catch (error) {
      if (error is PostgrestException) rethrow;
      await _offline.enqueue(client.auth.currentUser!.id, {
        'rpc': 'create_purchase_cart',
        'params': params,
      });
    }
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
    await _offline.enqueue(client.auth.currentUser!.id, {
      'rpc': 'create_sale',
      'params': params,
    });
    developer.log(
      'Sale queued for offline sync',
      name: 'SaiMate.Supabase',
      error: lastError,
    );
  }

  @override
  Future<void> createPurchase({
    required String productId,
    required int quantity,
  }) async {
    final params = {
      'p_shop_id': await _shop(),
      'p_product_id': productId,
      'p_quantity': quantity,
    };
    try {
      await client.rpc('create_purchase', params: params);
    } catch (error) {
      if (error is PostgrestException) rethrow;
      await _offline.enqueue(client.auth.currentUser!.id, {
        'rpc': 'create_purchase',
        'params': params,
      });
    }
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
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    try {
      await _syncPending(user.id);
      final state = await _loadRemote();
      await _offline.write(user.id, state);
      return state;
    } catch (error, stack) {
      developer.log(
        'Remote shop load failed',
        name: 'SaiMate.Supabase',
        error: error,
        stackTrace: stack,
      );
      if (error is PostgrestException || error is AuthException) rethrow;
      final cached = await _offline.read(user.id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> _syncPending(String userId) async {
    final commands = await _offline.pending(userId);
    final remaining = <Map<String, dynamic>>[];
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];
      try {
        if (command['kind'] == 'insert') {
          await client
              .from(command['table'] as String)
              .insert(command['values'] as Map<String, dynamic>);
        } else {
          await client.rpc(
            command['rpc'] as String,
            params: command['params'] as Map<String, dynamic>,
          );
        }
      } on PostgrestException catch (error, stack) {
        final migrated =
            error.code == 'PGRST202' &&
            command['rpc'] == 'create_purchase_cart' &&
            await _syncLegacyPurchase(command);
        if (migrated) continue;
        developer.log(
          'Queued command could not be synchronized',
          name: 'SaiMate.Supabase',
          error: error,
          stackTrace: stack,
        );
        remaining.addAll(commands.skip(i));
        break;
      } catch (error, stack) {
        developer.log(
          'Queued command could not be synchronized',
          name: 'SaiMate.Supabase',
          error: error,
          stackTrace: stack,
        );
        remaining.addAll(commands.skip(i));
        break;
      }
    }
    await _offline.replaceQueue(userId, remaining);
  }

  Future<bool> _syncLegacyPurchase(Map<String, dynamic> command) async {
    final params = command['params'] as Map<String, dynamic>?;
    final rawItems = params?['p_items'];
    if (params == null || rawItems is! List || rawItems.length != 1) {
      return false;
    }
    final item = Map<String, dynamic>.from(rawItems.single as Map);
    final productId = item['product_id'] as String?;
    final quantity = (item['quantity'] as num?)?.toInt();
    if (productId == null || quantity == null || quantity <= 0) return false;
    final unitCost = (item['unit_cost'] as num?)?.toInt();
    if (unitCost != null) {
      await client
          .from('products')
          .update({'cost_price': unitCost})
          .eq('id', productId)
          .eq('shop_id', params['p_shop_id']);
    }
    await client.rpc(
      'create_purchase',
      params: {
        'p_shop_id': params['p_shop_id'],
        'p_product_id': productId,
        'p_quantity': quantity,
      },
    );
    developer.log(
      'Synchronized queued purchase with legacy RPC',
      name: 'SaiMate.Supabase',
    );
    return true;
  }

  Future<ShopState> _loadRemote() async {
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
    final productRows = (results[2] as List).cast<Map<String, dynamic>>();
    final products = await Future.wait(
      productRows.map((row) async {
        final imagePath = row['image_path'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          row['_image_url'] = await client.storage
              .from('product-images')
              .createSignedUrl(imagePath, 3600);
        }
        return Product.fromJson(row);
      }),
    );
    return ShopState(
      shopName: shopRow['name'] as String? ?? 'Sai Mate',
      ownerName: profileRow['full_name'] as String? ?? '',
      products: products,
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
                    'movement_type': m.type.databaseValue,
                    'quantity': m.quantity,
                    'created_at': m.createdAt.toIso8601String(),
                  },
                )
                .toList(),
          );
    }
  }
}

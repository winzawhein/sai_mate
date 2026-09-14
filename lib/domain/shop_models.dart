enum MovementType { sale, purchase, adjustment, itemReturn }

extension MovementTypeValue on MovementType {
  String get databaseValue => switch (this) {
    MovementType.itemReturn => 'return',
    _ => name,
  };

  static MovementType fromDatabase(Object? value) => switch (value) {
    'sale' => MovementType.sale,
    'purchase' => MovementType.purchase,
    'return' => MovementType.itemReturn,
    _ => MovementType.adjustment,
  };
}

class CartLine {
  const CartLine({required this.product, required this.quantity});
  final Product product;
  final int quantity;
  int get total => product.salePrice * quantity;
  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
}

class TransactionLine {
  const TransactionLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
  final String productId, name;
  final int quantity, unitPrice;
  int get total => quantity * unitPrice;
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.sale,
    required this.total,
    required this.createdAt,
    required this.lines,
    this.partyName,
  });
  final String id;
  final bool sale;
  final int total;
  final DateTime createdAt;
  final String? partyName;
  final List<TransactionLine> lines;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.stock,
    required this.costPrice,
    required this.salePrice,
    required this.lowStockLimit,
    this.category = 'General',
    this.imagePath,
    this.imageUrl,
  });
  final String id, name, sku, category;
  final String? imagePath, imageUrl;
  final int stock, costPrice, salePrice, lowStockLimit;
  String get emoji => category == 'Beauty'
      ? '🧴'
      : category == 'Mobile'
      ? '📱'
      : category == 'Food'
      ? '🍪'
      : '📦';
  Product copyWith({
    String? name,
    String? sku,
    int? stock,
    int? costPrice,
    int? salePrice,
    int? lowStockLimit,
  }) => Product(
    id: id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    stock: stock ?? this.stock,
    costPrice: costPrice ?? this.costPrice,
    salePrice: salePrice ?? this.salePrice,
    lowStockLimit: lowStockLimit ?? this.lowStockLimit,
    category: category,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    sku: j['sku'] as String? ?? '',
    stock: (j['stock_quantity'] as num).toInt(),
    costPrice: (j['cost_price'] as num).toInt(),
    salePrice: (j['sale_price'] as num).toInt(),
    lowStockLimit: (j['low_stock_limit'] as num).toInt(),
    category:
        (j['categories'] as Map<String, dynamic>?)?['name'] as String? ??
        'General',
    imagePath: j['image_path'] as String?,
    imageUrl: j['_image_url'] as String?,
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.note = '',
    this.debt = 0,
  });
  final String id, name, phone, address, note;
  final int debt;
  Customer copyWith({String? name, String? phone, String? address}) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    note: note,
    debt: debt,
  );
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    address: j['address'] as String? ?? '',
    debt: (j['balance'] as num?)?.toInt() ?? 0,
  );
}

class Supplier {
  const Supplier({required this.id, required this.name, required this.phone});
  final String id, name, phone;
  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
  );
}

class Debt {
  const Debt({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.paid,
    required this.createdAt,
  });
  final String id, customerId;
  final int amount, paid;
  final DateTime createdAt;
  int get balance => amount - paid;
  Debt copyWith({int? paid}) => Debt(
    id: id,
    customerId: customerId,
    amount: amount,
    paid: paid ?? this.paid,
    createdAt: createdAt,
  );
  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
    id: j['id'] as String,
    customerId: j['customer_id'] as String,
    amount: (j['amount'] as num).toInt(),
    paid: (j['paid'] as num).toInt(),
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.type,
    required this.total,
    required this.createdAt,
  });
  final String id, productId;
  final int quantity, total;
  final MovementType type;
  final DateTime createdAt;
  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    id: j['id'] as String,
    productId: j['product_id'] as String,
    quantity: (j['quantity'] as num).toInt(),
    type: MovementTypeValue.fromDatabase(j['movement_type']),
    total: 0,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class ShopState {
  const ShopState({
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.debts,
    required this.movements,
    this.salesTotal,
    this.shopName = 'Sai Mate',
    this.ownerName = '',
  });
  final List<Product> products;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<Debt> debts;
  final List<StockMovement> movements;
  final int? salesTotal;
  final String shopName, ownerName;
  int get outstandingDebt => debts.fold(0, (sum, d) => sum + d.balance);
  int get inventoryValue =>
      products.fold(0, (sum, p) => sum + p.stock * p.costPrice);
  int get monthlySales =>
      salesTotal ??
      movements
          .where(
            (m) =>
                m.type == MovementType.sale &&
                m.createdAt.month == DateTime.now().month,
          )
          .fold(0, (sum, m) => sum + m.total);
  ShopState copyWith({
    List<Product>? products,
    List<Customer>? customers,
    List<Supplier>? suppliers,
    List<Debt>? debts,
    List<StockMovement>? movements,
    int? salesTotal,
    String? shopName,
    String? ownerName,
  }) => ShopState(
    products: products ?? this.products,
    customers: customers ?? this.customers,
    suppliers: suppliers ?? this.suppliers,
    debts: debts ?? this.debts,
    movements: movements ?? this.movements,
    salesTotal: salesTotal ?? this.salesTotal,
    shopName: shopName ?? this.shopName,
    ownerName: ownerName ?? this.ownerName,
  );
}

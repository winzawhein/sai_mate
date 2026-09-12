import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

class InMemoryShopRepository implements ShopRepository {
  ShopState _state = ShopState(
    products: const [
      Product(
        id: 'p1',
        name: 'Shampoo 650ml',
        sku: 'SKU-204',
        stock: 42,
        costPrice: 6200,
        salePrice: 8500,
        lowStockLimit: 10,
        category: 'Beauty',
      ),
      Product(
        id: 'p2',
        name: 'Type-C Cable',
        sku: 'SKU-118',
        stock: 8,
        costPrice: 7500,
        salePrice: 12000,
        lowStockLimit: 10,
        category: 'Mobile',
      ),
      Product(
        id: 'p3',
        name: 'Oreo 133g',
        sku: 'SKU-087',
        stock: 3,
        costPrice: 1300,
        salePrice: 1800,
        lowStockLimit: 6,
        category: 'Food',
      ),
      Product(
        id: 'p4',
        name: 'Coffee Mix 20s',
        sku: 'SKU-031',
        stock: 24,
        costPrice: 4800,
        salePrice: 6500,
        lowStockLimit: 8,
        category: 'Food',
      ),
    ],
    customers: const [
      Customer(
        id: 'c1',
        name: 'မမိုး',
        phone: '09 421 555 200',
        note: '2 ရက်က · ဖုန်းဆက်ရန်',
        debt: 125000,
      ),
      Customer(
        id: 'c2',
        name: 'ကိုအောင်',
        phone: '09 770 322 144',
        note: '5 ရက်က · သတိပေးရန်',
        debt: 86500,
      ),
    ],
    suppliers: const [
      Supplier(id: 's1', name: 'Golden Distribution', phone: '09 500 100 200'),
    ],
    debts: [
      Debt(
        id: 'd1',
        customerId: 'c1',
        amount: 125000,
        paid: 0,
        createdAt: DateTime.now(),
      ),
      Debt(
        id: 'd2',
        customerId: 'c2',
        amount: 86500,
        paid: 0,
        createdAt: DateTime.now(),
      ),
    ],
    movements: const [],
  );
  @override
  Future<ShopState> load() async => _state;
  @override
  Future<void> save(ShopState state) async {
    _state = state;
  }
}

# Sai Mate Supabase setup

1. Create a Supabase project and open **SQL Editor**.
2. Run [`supabase/schema.sql`](supabase/schema.sql) once.
3. Run [`supabase/bootstrap.sql`](supabase/bootstrap.sql) once. This creates the signup trigger and private product image bucket.
4. In Authentication, enable Email/Password. Add phone OTP later only if you have an SMS provider.
5. The Flutter project initializes Supabase using compile-time variables:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

Run without committing secrets:

```bash
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

After signup, create the profile, shop, and owner membership in one server-side database function or Edge Function. Never put the service-role key in Flutter.

Useful Flutter queries:

```dart
final products = await supabase.from('products').select().eq('shop_id', shopId).isFilter('deleted_at', null).order('name');
await supabase.from('products').insert({'shop_id':shopId,'name':name,'sku':sku,'cost_price':cost,'sale_price':price});
await supabase.from('customers').update({'name':name,'updated_at':DateTime.now().toIso8601String()}).eq('id',customerId);
final balances = await supabase.from('customer_balances').select().eq('shop_id',shopId).order('balance',ascending:false);
final lowStock = await supabase.from('low_stock_products').select().eq('shop_id',shopId);
```

For a sale, use a PostgreSQL RPC transaction that inserts `sales`, `sale_items`, `stock_movements`, updates product stock, and optionally creates a debt. Do not execute those writes independently from Flutter because a partial failure would corrupt inventory totals.

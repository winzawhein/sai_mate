import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/shop_controller.dart';

typedef BillingRow = Map<String, dynamic>;

final subscriptionRepositoryProvider = Provider((ref) {
  ref.watch(signedInUserProvider);
  return SubscriptionRepository(Supabase.instance.client);
});
final subscriptionOverviewProvider = FutureProvider(
  (ref) => ref.watch(subscriptionRepositoryProvider).load(),
);

class SubscriptionOverview {
  const SubscriptionOverview({
    required this.shopId,
    required this.owner,
    required this.reviewer,
    required this.plans,
    required this.methods,
    required this.payments,
    this.subscription,
  });
  final String shopId;
  final bool owner, reviewer;
  final List<BillingRow> plans, methods, payments;
  final BillingRow? subscription;
  bool get pending => payments.any((p) => p['status'] == 'pending');
  bool get active =>
      subscription != null &&
      DateTime.parse(subscription!['expires_at'] as String)
          .isAfter(DateTime.now());
}

String slipExtension(Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('ပုံအရွယ်အစား 5 MB ထက် မကျော်ရပါ။');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= 8 &&
      List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
    return 'png';
  }
  throw const FormatException('JPG သို့မဟုတ် PNG ပုံကို ရွေးပါ။');
}

class SubscriptionRepository {
  SubscriptionRepository(this.client);
  final SupabaseClient client;
  Future<SubscriptionOverview> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in');
    final member = await client
        .from('shop_members')
        .select('shop_id')
        .eq('user_id', user.id)
        .limit(1)
        .single();
    final shopId = member['shop_id'] as String;
    final shop = await client
        .from('shops')
        .select('owner_id')
        .eq('id', shopId)
        .single();
    final results = await Future.wait<dynamic>([
      client.rpc('is_billing_reviewer'),
      client
          .from('subscription_plans')
          .select()
          .eq('active', true)
          .order('price'),
      client
          .from('subscription_payment_methods')
          .select()
          .eq('active', true)
          .order('name'),
      client
          .from('subscription_payments')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(20),
      client
          .from('shop_subscriptions')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle(),
    ]);
    return SubscriptionOverview(
      shopId: shopId,
      owner: shop['owner_id'] == user.id,
      reviewer: results[0] == true,
      plans: List<BillingRow>.from(results[1] as List),
      methods: List<BillingRow>.from(results[2] as List),
      payments: List<BillingRow>.from(results[3] as List),
      subscription: results[4] as BillingRow?,
    );
  }

  Future<List<BillingRow>> history(String shopId, int offset) async =>
      await client
          .from('subscription_payments')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 19);
  Future<List<BillingRow>> queue(int offset) async => await client
      .from('subscription_payments')
      .select()
      .eq('status', 'pending')
      .order('created_at')
      .order('id')
      .range(offset, offset + 19);
  Future<String> upload(String id, Uint8List bytes) async {
    final ext = slipExtension(bytes);
    final path = '${client.auth.currentUser!.id}/$id.$ext';
    try {
      await client.storage
          .from('subscription-slips')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'jpg' ? 'image/jpeg' : 'image/png',
            ),
          );
    } on StorageException catch (e) {
      // A timed-out upload may already have succeeded. Paths are immutable and
      // unique per checkout, so retrying the same request can reuse its object.
      if (e.statusCode != '409' && e.error != 'Duplicate') rethrow;
    }
    return path;
  }

  Future<void> submit({
    required String id,
    required String shopId,
    required BillingRow plan,
    required BillingRow method,
    required String reference,
    required DateTime paidAt,
    required String path,
  }) async {
    await client.rpc(
      'submit_subscription_payment',
      params: {
        'p_id': id,
        'p_shop_id': shopId,
        'p_plan_id': plan['id'],
        'p_method_id': method['id'],
        'p_reference': reference.trim(),
        'p_paid_at': paidAt.toUtc().toIso8601String(),
        'p_slip_path': path,
        'p_expected_price': plan['price'],
        'p_expected_days': plan['duration_days'],
        'p_expected_account': method['account_number'],
      },
    );
  }

  Future<Uint8List> slip(String path) =>
      client.storage.from('subscription-slips').download(path);
  Future<void> review(String id, bool approve, String note) async {
    await client.rpc(
      'review_subscription_payment',
      params: {'p_id': id, 'p_approve': approve, 'p_note': note},
    );
  }

  Future<List<BillingRow>> config(bool plans) async => await client
      .from(plans ? 'subscription_plans' : 'subscription_payment_methods')
      .select()
      .order('created_at');
  Future<void> saveConfig(bool plans, BillingRow data) async {
    await client
        .from(plans ? 'subscription_plans' : 'subscription_payment_methods')
        .upsert(data);
  }
}

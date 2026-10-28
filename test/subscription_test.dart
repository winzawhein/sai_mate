import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_mate/data/subscription_repository.dart';
import 'package:sai_mate/presentation/subscription_page.dart';

final plan = <String, dynamic>{
  'id': 'plan',
  'name': 'Monthly',
  'price': 10000,
  'duration_days': 30,
  'description': 'Test plan',
};
final method = <String, dynamic>{
  'id': 'method',
  'name': 'Test Bank',
  'account_name': 'Test Recipient',
  'account_number': 'TEST-1234',
  'instructions': '',
};
SubscriptionOverview overview({
  bool pending = false,
  bool owner = true,
  bool configured = true,
}) => SubscriptionOverview(
  shopId: 'shop',
  owner: owner,
  reviewer: false,
  plans: [plan],
  methods: configured ? [method] : [],
  payments: pending
      ? [
          {
            'id': 'payment',
            'status': 'pending',
            'plan_name': 'Monthly',
            'amount': 10000,
            'created_at': '2026-10-02T00:00:00Z',
            'method_name': 'Test Bank',
            'transaction_reference': 'TEST-REF',
          },
        ]
      : [],
);
void main() {
  test('slip validation rejects invalid and oversized files', () {
    expect(slipExtension(Uint8List.fromList([255, 216, 255, 0])), 'jpg');
    expect(
      slipExtension(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
      'png',
    );
    expect(
      () => slipExtension(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => slipExtension(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
  for (final scenario in ['pending', 'staff', 'no account']) {
    testWidgets('checkout disabled for $scenario', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionOverviewProvider.overrideWith(
              (ref) async => overview(
                pending: scenario == 'pending',
                owner: scenario != 'staff',
                configured: scenario != 'no account',
              ),
            ),
          ],
          child: const MaterialApp(home: SubscriptionPage()),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'ရွေးချယ်မည်');
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'checkout validates reference and missing slip without uploading',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SubscriptionCheckout(data: overview(), plan: plan),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reference = find.byType(TextFormField);
      await tester.ensureVisible(reference);
      await tester.enterText(reference, 'TEST-TRANSFER');
      final submit = find.widgetWithText(FilledButton, 'စစ်ဆေးရန် ပို့မည်');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('ငွေလွှဲပြေစာ ထည့်ပါ။'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

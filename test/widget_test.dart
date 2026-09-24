import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_mate/data/in_memory_shop_repository.dart';
import 'package:sai_mate/main.dart';
import 'package:sai_mate/presentation/shop_controller.dart';

void main() {
  testWidgets('shows the Sai Mate dashboard and navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(InMemoryShopRepository()),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('အမြန်လုပ်ဆောင်ရန်'), findsOneWidget);
    expect(find.text('ပစ္စည်းလက်ကျန်'), findsOneWidget);
    expect(find.text('ရောင်းမည်'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}

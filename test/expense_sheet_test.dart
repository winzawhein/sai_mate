import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_mate/presentation/advanced_reports_page.dart';

void main() {
  testWidgets('expense sheet survives keyboard, dismissal, and reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ExpenseEntrySheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Rent');
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(ExpenseEntrySheet))).pop();
      await tester.pump(const Duration(milliseconds: 80));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

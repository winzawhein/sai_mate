import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';
import 'shop_controller.dart';

const _green = Color(0xFF1C6D5B), _orange = Color(0xFFFF9E63);

enum ReportPeriod { week, month, year }

enum TransactionFilter { all, sales, purchases }

final reportPeriodProvider = StateProvider<ReportPeriod>(
  (ref) => ReportPeriod.month,
);
final transactionFilterProvider = StateProvider.autoDispose<TransactionFilter>(
  (ref) => TransactionFilter.all,
);
final transactionQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final transactionHistoryProvider = FutureProvider<List<TransactionRecord>>((
  ref,
) async {
  // A completed sale or purchase refreshes shopProvider. Watching it here
  // invalidates the cached history immediately, even while this tab remains
  // mounted inside the app's IndexedStack.
  ref.watch(shopProvider);
  final repo = ref.watch(repositoryProvider);
  if (repo is! HistoryRepository) return const [];
  return (repo as HistoryRepository).loadTransactions();
});

class AdvancedReportsPage extends ConsumerWidget {
  const AdvancedReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transactionHistoryProvider);
    final period = ref.watch(reportPeriodProvider);
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(
                'အစီရင်ခံစာ',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
            ),
            const TabBar(
              labelColor: _green,
              indicatorColor: _green,
              tabs: [
                Tab(text: 'သုံးသပ်ချက်'),
                Tab(text: 'မှတ်တမ်း'),
              ],
            ),
            Expanded(
              child: history.when(
                data: (records) => TabBarView(
                  children: [
                    ReportOverview(records: records, period: period),
                    TransactionHistory(records: records),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportOverview extends ConsumerWidget {
  const ReportOverview({
    super.key,
    required this.records,
    required this.period,
  });
  final List<TransactionRecord> records;
  final ReportPeriod period;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final start = period == ReportPeriod.week
        ? now.subtract(const Duration(days: 7))
        : period == ReportPeriod.month
        ? DateTime(now.year, now.month)
        : DateTime(now.year);
    final filtered = records.where((r) => r.createdAt.isAfter(start)).toList();
    final sales = filtered
        .where((r) => r.sale)
        .fold<int>(0, (s, r) => s + r.total);
    final purchases = filtered
        .where((r) => !r.sale)
        .fold<int>(0, (s, r) => s + r.total);
    final profit = filtered
        .where((record) => record.sale)
        .fold<int>(0, (sum, record) => sum + record.grossProfit);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SegmentedButton<ReportPeriod>(
          segments: const [
            ButtonSegment(value: ReportPeriod.week, label: Text('၇ ရက်')),
            ButtonSegment(value: ReportPeriod.month, label: Text('ဒီလ')),
            ButtonSegment(value: ReportPeriod.year, label: Text('ဒီနှစ်')),
          ],
          selected: {period},
          onSelectionChanged: (v) =>
              ref.read(reportPeriodProvider.notifier).state = v.first,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'ရောင်းအား',
                value: sales,
                color: _green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                title: 'အဝယ်',
                value: purchases,
                color: _orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MetricCard(
          title: 'အကြမ်းအမြတ်',
          value: profit,
          color: profit >= 0 ? _green : Colors.red,
        ),
        const SizedBox(height: 18),
        Text(
          'လုပ်ဆောင်မှု ${filtered.length} ခု',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });
  final String title;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 11)),
        const SizedBox(height: 6),
        Text(
          '${NumberFormat('#,##0').format(value)} Ks',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class TransactionHistory extends ConsumerWidget {
  const TransactionHistory({super.key, required this.records});
  final List<TransactionRecord> records;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final query = ref.watch(transactionQueryProvider).trim().toLowerCase();
    final filtered = records.where((record) {
      final typeMatches = switch (filter) {
        TransactionFilter.all => true,
        TransactionFilter.sales => record.sale,
        TransactionFilter.purchases => !record.sale,
      };
      if (!typeMatches) return false;
      if (query.isEmpty) return true;
      return (record.partyName?.toLowerCase().contains(query) ?? false) ||
          record.lines.any((line) => line.name.toLowerCase().contains(query));
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (value) =>
                    ref.read(transactionQueryProvider.notifier).state = value,
                decoration: const InputDecoration(
                  hintText: 'ဖောက်သည်၊ ပေးသွင်းသူ၊ ပစ္စည်း ရှာရန်',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TransactionFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionFilter.all,
                      label: Text('အားလုံး'),
                    ),
                    ButtonSegment(
                      value: TransactionFilter.sales,
                      label: Text('အရောင်း'),
                    ),
                    ButtonSegment(
                      value: TransactionFilter.purchases,
                      label: Text('အဝယ်'),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (values) =>
                      ref.read(transactionFilterProvider.notifier).state =
                          values.first,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('ကိုက်ညီသော မှတ်တမ်းမရှိပါ'))
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => TransactionTile(record: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.record});
  final TransactionRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: Colors.white.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .6,
        ),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: shape,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: shape,
          collapsedShape: shape,
          leading: CircleAvatar(
            backgroundColor: (record.sale ? _green : _orange).withValues(
              alpha: .14,
            ),
            child: Icon(
              record.sale ? Icons.north_east : Icons.south_west,
              color: record.sale ? _green : _orange,
            ),
          ),
          title: Text(
            record.sale ? 'အရောင်း' : 'အဝယ်',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${DateFormat('dd MMM yyyy, HH:mm').format(record.createdAt.toLocal())}${record.partyName == null ? '' : ' · ${record.partyName}'}',
          ),
          trailing: Text(
            '${NumberFormat('#,##0').format(record.total)} Ks',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          children: record.lines
              .map(
                (line) => ListTile(
                  title: Text(line.name),
                  subtitle: Text(
                    '${line.quantity} × ${NumberFormat('#,##0').format(line.unitPrice)}',
                  ),
                  trailing: record.sale
                      ? TextButton(
                          onPressed: () => _return(context, ref, line),
                          child: const Text('ပြန်အပ်'),
                        )
                      : null,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _return(
    BuildContext context,
    WidgetRef ref,
    TransactionLine line,
  ) async {
    final repo = ref.read(repositoryProvider);
    if (repo is! HistoryRepository) return;
    try {
      await (repo as HistoryRepository).returnSaleItem(
        saleId: record.id,
        productId: line.productId,
        quantity: 1,
      );
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(shopProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ပစ္စည်း ၁ ခု ပြန်အပ်ပြီးပါပြီ'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/shop_models.dart';

const _lime = Color(0xFFA5EF55);
const _yellow = Color(0xFFFFEA4D);
const _ink = Color(0xFF101010);
String _money(int amount) => '${NumberFormat('#,##0').format(amount)} Ks';

class DashboardMetric extends StatelessWidget {
  const DashboardMetric({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String title, subtitle;
  final int value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x55000000), offset: Offset(4, 5)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CircleAvatar(
              radius: 13,
              backgroundColor: _ink,
              child: Icon(icon, size: 15, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF39452F), fontSize: 10),
        ),
        const SizedBox(height: 25),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _money(value),
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class DashboardInsights extends StatelessWidget {
  const DashboardInsights({super.key, required this.records});
  final List<TransactionRecord> records;
  @override
  Widget build(BuildContext context) {
    final sales = records.where((r) => r.sale).toList();
    // Unknown methods remain explicit rather than being represented as cash.
    final amounts = <String, int>{
      'Cash': 0,
      'Mobile Pay': 0,
      'Credit / Other': 0,
    };
    final units = <String, int>{};
    final names = <String, String>{};
    for (final sale in sales) {
      final paid = (sale.paid ?? 0).clamp(0, sale.total);
      final key = sale.paymentMethod == 'cash'
          ? 'Cash'
          : sale.paymentMethod == 'mobile'
          ? 'Mobile Pay'
          : 'Credit / Other';
      amounts[key] = amounts[key]! + paid;
      amounts['Credit / Other'] =
          amounts['Credit / Other']! + sale.total - paid;
      for (final line in sale.lines) {
        units.update(
          line.productId,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
        names[line.productId] = line.name;
      }
    }
    final total = amounts.values.fold<int>(0, (sum, value) => sum + value);
    final ranked = units.keys.toList()
      ..sort((a, b) => units[b]!.compareTo(units[a]!));
    final best = ranked.isEmpty ? null : ranked.first;
    final colors = [_lime, _yellow, const Color(0xFF92929A)];
    final surface = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF202020)
        : const Color(0xFFF1F1F1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ငွေပေးချေမှု အမျိုးအစား',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (i) {
            final entry = amounts.entries.elementAt(i);
            final ratio = total == 0 ? 0.0 : entry.value / total;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), offset: Offset(4, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          color: colors[i],
                          backgroundColor: Colors.grey.withValues(alpha: .25),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            color: _yellow,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'အရောင်းအများဆုံး ပစ္စည်း',
                      style: TextStyle(color: _ink, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      best == null ? 'အရောင်း မရှိသေးပါ' : names[best]!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${best == null ? 0 : units[best]} ခု',
                  style: const TextStyle(color: _lime, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

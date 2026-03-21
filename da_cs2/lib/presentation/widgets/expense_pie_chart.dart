import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/providers/money_formatter_provider.dart';

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.userId});

  final String? userId;

  Stream<List<Map<String, dynamic>>> _getTransactionsStream() {
    if (userId == null) return Stream.value([]);

    return Supabase.instance.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId!)
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTransactionsStream(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];

        // Tính tổng chi tiêu theo danh mục
        final Map<String, double> totals = {};
        for (final item in items) {
          final amount = MoneyFormatter.asNum(item['amount']).toDouble();
          if (amount >= 0) continue; // Chỉ lấy chi tiêu (số âm)
          final title = (item['title'] ?? '').toString().trim();
          final key = title.isEmpty ? 'Khác' : title;
          totals[key] = (totals[key] ?? 0) + amount.abs();
        }

        if (totals.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Chưa có dữ liệu chi tiêu để vẽ biểu đồ'),
            ),
          );
        }

        final entries = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Hiển thị tối đa 6 danh mục, cộng phần còn lại vào "Khác"
        const maxSlices = 6;
        final visible = entries.take(maxSlices).toList();
        final rest = entries
            .skip(maxSlices)
            .fold<double>(0, (sum, e) => sum + e.value);
        if (rest > 0) visible.add(MapEntry('Khác', rest));

        // Màu sắc cho biểu đồ
        const colors = <Color>[
          Colors.blue,
          Colors.red,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.brown,
        ];

        final total = visible.fold<double>(0, (sum, e) => sum + e.value);
        final sections = <PieChartSectionData>[];
        for (var i = 0; i < visible.length; i++) {
          final e = visible[i];
          final pct = total == 0 ? 0 : (e.value / total) * 100;
          sections.add(
            PieChartSectionData(
              value: e.value,
              color: colors[i % colors.length],
              radius: 70,
              title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...visible.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final color = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormatter.formatMoney(e.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/providers/money_formatter_provider.dart';
import './transaction_item.dart';

class TransactionsList extends StatelessWidget {
  const TransactionsList({
    super.key,
    required this.userId,
    this.limit,
    this.isScrollable = false,
  });

  final String? userId;
  final int? limit;
  final bool isScrollable;

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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: Text("Chưa có giao dịch nào")),
          );
        }

        final transactions = limit == null
            ? snapshot.data!
            : snapshot.data!.take(limit!).toList();

        if (isScrollable) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final item = transactions[index];
              final title = (item['title'] ?? '').toString().trim();
              final amount = MoneyFormatter.asNum(item['amount']);
              return TransactionItem(
                title: title.isEmpty ? 'Giao dịch' : title,
                amount: MoneyFormatter.formatMoney(amount),
              );
            },
          );
        }

        return Column(
          children: transactions.map((item) {
            final title = (item['title'] ?? '').toString().trim();
            final amount = MoneyFormatter.asNum(item['amount']);
            return TransactionItem(
              title: title.isEmpty ? 'Giao dịch' : title,
              amount: MoneyFormatter.formatMoney(amount),
            );
          }).toList(),
        );
      },
    );
  }
}

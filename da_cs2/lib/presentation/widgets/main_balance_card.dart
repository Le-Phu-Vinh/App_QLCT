import 'package:flutter/material.dart';
import '../../logic/providers/money_formatter_provider.dart';
import './expense_pie_chart.dart';

class MainBalanceCard extends StatelessWidget {
  const MainBalanceCard({
    super.key,
    required this.balance,
    required this.userId,
  });

  final num balance;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tổng số dư: ${MoneyFormatter.formatMoney(balance)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ExpensePieChart(userId: userId),
        ],
      ),
    );
  }
}

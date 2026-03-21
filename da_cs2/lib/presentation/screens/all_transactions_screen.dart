import 'package:flutter/material.dart';
import '../../logic/providers/profile_provider.dart';
import '../../logic/services/auth_service.dart';
import '../../logic/providers/money_formatter_provider.dart';
import '../widgets/transactions_list.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().getCurrentUser();

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả giao dịch')),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng quan tài khoản',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TransactionsList(
                      userId: user.id,
                      isScrollable: true,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

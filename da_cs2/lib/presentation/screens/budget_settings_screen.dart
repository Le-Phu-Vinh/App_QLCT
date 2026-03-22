import 'package:flutter/material.dart';
import '../../logic/providers/budget_goal_provider.dart';
import '../../logic/services/auth_service.dart';
import '../../models/budget_goal.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _budgetProvider = BudgetGoalProvider();
  final _authService = AuthService();

  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUser()?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt ngân sách')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mục tiêu ngân sách mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Loại giao dịch',
                hintText: 'Ví dụ: Ăn uống, Di chuyển, Mua sắm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số tiền mục tiêu (VNĐ)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Tháng: '),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(month.toString()),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMonth = value);
                    }
                  },
                ),
                const SizedBox(width: 16),
                const Text('Năm: '),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedYear = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _addBudgetGoal(userId),
              child: const Text('Thêm mục tiêu'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Mục tiêu hiện tại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<BudgetGoal>>(
                stream: _budgetProvider.getBudgetGoalsStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Chưa có mục tiêu nào'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final goal = snapshot.data![index];
                      return Card(
                        child: ListTile(
                          title: Text(goal.category),
                          subtitle: Text(
                            'Mục tiêu: ${goal.targetAmount.toStringAsFixed(0)} VNĐ - ${goal.month}/${goal.year}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteBudgetGoal(goal.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBudgetGoal(String? userId) async {
    if (userId == null) return;

    final category = _categoryController.text.trim();
    final amountText = _amountController.text.trim();

    if (category.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    final amount = num.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ')));
      return;
    }

    try {
      await _budgetProvider.createBudgetGoal(
        userId: userId,
        category: category,
        targetAmount: amount,
        month: _selectedMonth,
        year: _selectedYear,
      );

      _categoryController.clear();
      _amountController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm mục tiêu ngân sách')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteBudgetGoal(String goalId) async {
    try {
      await _budgetProvider.deleteBudgetGoal(goalId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa mục tiêu')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
}

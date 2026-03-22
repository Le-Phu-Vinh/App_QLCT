import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../models/budget_goal.dart';

/// Provider quản lý mục tiêu ngân sách
class BudgetGoalProvider {
  static final BudgetGoalProvider _instance = BudgetGoalProvider._internal();

  factory BudgetGoalProvider() => _instance;

  BudgetGoalProvider._internal();

  final _supabase = Supabase.instance.client;

  /// Lấy stream budget goals của người dùng
  Stream<List<BudgetGoal>> getBudgetGoalsStream(String? userId) {
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from(AppConstants.budgetGoalsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => BudgetGoal.fromJson(json)).toList());
  }

  /// Tạo budget goal mới
  Future<void> createBudgetGoal({
    required String userId,
    required String category,
    required num targetAmount,
    required int month,
    required int year,
  }) async {
    try {
      await _supabase.from(AppConstants.budgetGoalsTable).insert({
        'user_id': userId,
        'category': category,
        'target_amount': targetAmount,
        'month': month,
        'year': year,
      });
    } catch (e) {
      print('Error creating budget goal: $e');
      rethrow;
    }
  }

  /// Cập nhật budget goal
  Future<void> updateBudgetGoal(BudgetGoal goal) async {
    try {
      await _supabase
          .from(AppConstants.budgetGoalsTable)
          .update(goal.toJson())
          .eq('id', goal.id);
    } catch (e) {
      print('Error updating budget goal: $e');
      rethrow;
    }
  }

  /// Xóa budget goal
  Future<void> deleteBudgetGoal(String goalId) async {
    try {
      await _supabase
          .from(AppConstants.budgetGoalsTable)
          .delete()
          .eq('id', goalId);
    } catch (e) {
      print('Error deleting budget goal: $e');
      rethrow;
    }
  }

  /// Lấy tổng chi tiêu theo category trong tháng
  Future<num> getMonthlyExpenseByCategory(
    String userId,
    String category,
    int month,
    int year,
  ) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final response = await _supabase
          .from(AppConstants.transactionsTable)
          .select('amount, title')
          .eq('user_id', userId)
          .lt('amount', 0) // Chi tiêu (âm)
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String());

      num total = 0;
      for (final row in response) {
        final title = row['title'] as String;
        // Giả sử category khớp với title (có thể cải thiện sau)
        if (title.contains(category) || category.contains(title)) {
          total += (row['amount'] as num).abs();
        }
      }

      return total;
    } catch (e) {
      print('Error getting monthly expense: $e');
      return 0;
    }
  }
}

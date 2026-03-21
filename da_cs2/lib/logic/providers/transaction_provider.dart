import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../logic/providers/profile_provider.dart';
import '../../logic/providers/money_formatter_provider.dart';

/// Provider quản lý giao dịch
class TransactionProvider {
  static final TransactionProvider _instance = TransactionProvider._internal();

  factory TransactionProvider() => _instance;

  TransactionProvider._internal();

  final _supabase = Supabase.instance.client;
  final _profileProvider = ProfileProvider();

  /// Lấy stream transactions của người dùng
  Stream<List<Map<String, dynamic>>> getTransactionsStream(String? userId) {
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from(AppConstants.transactionsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Tạo giao dịch mới
  Future<void> createTransaction({
    required String userId,
    required String title,
    required num amount,
    required bool isExpense,
  }) async {
    try {
      final signedAmount = isExpense ? -amount.abs() : amount.abs();

      // Thêm giao dịch vào bảng transactions
      await _supabase.from(AppConstants.transactionsTable).insert({
        'user_id': userId,
        'title': title,
        'amount': signedAmount,
      });

      // Tạo thông báo
      try {
        await _supabase.from(AppConstants.notificationsTable).insert({
          'user_id': userId,
          'type': 'transaction',
          'title': title,
          'body':
              '${isExpense ? "Chi" : "Thu"}: ${MoneyFormatter.formatMoney(amount.abs())}',
          'is_read': false,
        });
      } catch (_) {
        // Bảng notifications có thể chưa tồn tại
      }

      // Cập nhật profile totals
      await _updateProfileTotals(userId, signedAmount, isExpense, amount.abs());
    } catch (e) {
      print('Error creating transaction: $e');
      rethrow;
    }
  }

  /// Cập nhật tổng số dư, chi tiêu, và thu nhập
  Future<void> _updateProfileTotals(
    String userId,
    num signedAmount,
    bool isExpense,
    num absAmount,
  ) async {
    try {
      final profile = await _supabase
          .from(AppConstants.profilesTable)
          .select('balance, expense, income')
          .eq('id', userId)
          .single();

      final curBalance = MoneyFormatter.asNum(profile['balance']);
      final curExpense = MoneyFormatter.asNum(profile['expense']);
      final curIncome = MoneyFormatter.asNum(profile['income']);

      final nextBalance = curBalance + signedAmount;
      final nextExpense = isExpense ? (curExpense + absAmount) : curExpense;
      final nextIncome = isExpense ? curIncome : (curIncome + absAmount);

      await _profileProvider.updateProfile(
        userId: userId,
        balance: nextBalance,
        expense: nextExpense,
        income: nextIncome,
      );
    } catch (e) {
      print('Error updating profile totals: $e');
      rethrow;
    }
  }
}

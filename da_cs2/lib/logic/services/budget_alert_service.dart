import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/budget_goal_provider.dart';
import '../../models/budget_goal.dart';

/// Service quản lý cảnh báo ngân sách
class BudgetAlertService {
  static final BudgetAlertService _instance = BudgetAlertService._internal();

  factory BudgetAlertService() => _instance;

  BudgetAlertService._internal();

  final _budgetProvider = BudgetGoalProvider();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Khởi tạo notifications
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  /// Kiểm tra và gửi cảnh báo cho tất cả budget goals của user
  Future<void> checkAndSendAlerts(String userId) async {
    final goals = await _budgetProvider.getBudgetGoalsStream(userId).first;

    for (final goal in goals) {
      await _checkSingleGoal(userId, goal);
    }
  }

  /// Kiểm tra một goal cụ thể
  Future<void> _checkSingleGoal(String userId, BudgetGoal goal) async {
    final now = DateTime.now();
    if (goal.month != now.month || goal.year != now.year) {
      return; // Chỉ kiểm tra goals của tháng hiện tại
    }

    final currentExpense = await _budgetProvider.getMonthlyExpenseByCategory(
      userId,
      goal.category,
      goal.month,
      goal.year,
    );

    if (currentExpense > goal.targetAmount) {
      await _sendAlertNotification(goal, currentExpense);
    }
  }

  /// Gửi thông báo cảnh báo
  Future<void> _sendAlertNotification(
    BudgetGoal goal,
    num currentExpense,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Cảnh báo ngân sách',
      channelDescription: 'Thông báo khi vượt quá mục tiêu chi tiêu',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final overAmount = currentExpense - goal.targetAmount;
    final body =
        'Bạn đã chi tiêu ${currentExpense.toStringAsFixed(0)} VNĐ cho ${goal.category}, vượt quá mục tiêu ${goal.targetAmount.toStringAsFixed(0)} VNĐ (${overAmount.toStringAsFixed(0)} VNĐ)';

    await _notificationsPlugin.show(
      goal.id.hashCode, // Unique ID
      'Cảnh báo chi tiêu',
      body,
      details,
    );
  }
}

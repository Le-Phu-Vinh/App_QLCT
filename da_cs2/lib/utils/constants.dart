import 'package:flutter/services.dart';

/// Constants for app configuration
class AppConstants {
  static const String bankNotifChannel = 'bank_notifications';

  // Bank schemes for deep linking
  static const List<({String name, String scheme})> banks = [
    (name: 'MB Bank', scheme: 'mbbank://'),
    (name: 'Vietcombank', scheme: 'vcb://'),
    (name: 'Techcombank', scheme: 'tcb://'),
    (name: 'ACB', scheme: 'acb://'),
    (name: 'BIDV', scheme: 'bidvsmartbanking://'),
  ];

  static const EventChannel bankEventChannel = EventChannel(bankNotifChannel);

  // SharedPreferences keys
  static const String linkedBankSchemeKey = 'linked_bank_scheme';
  static const String userAvatarKey = 'user_avatar';

  // Supabase table names
  static const String transactionsTable = 'transactions';
  static const String profilesTable = 'profiles';
  static const String notificationsTable = 'notifications';
  static const String budgetGoalsTable = 'budget_goals';
}

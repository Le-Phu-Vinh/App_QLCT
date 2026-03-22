class BudgetGoal {
  BudgetGoal({
    required this.id,
    required this.userId,
    required this.category,
    required this.targetAmount,
    required this.month,
    required this.year,
  });

  final String id;
  final String userId;
  final String category; // Loại giao dịch, ví dụ: "Ăn uống", "Di chuyển", etc.
  final num targetAmount;
  final int month; // 1-12
  final int year;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'target_amount': targetAmount,
      'month': month,
      'year': year,
    };
  }

  factory BudgetGoal.fromJson(Map<String, dynamic> json) {
    return BudgetGoal(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      targetAmount: json['target_amount'],
      month: json['month'],
      year: json['year'],
    );
  }
}

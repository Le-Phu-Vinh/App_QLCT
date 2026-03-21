class PendingTransaction {
  PendingTransaction({
    required this.rawPayload,
    required this.amount,
    required this.titleHint,
  });

  final String rawPayload;
  final num amount;
  final String titleHint;
}

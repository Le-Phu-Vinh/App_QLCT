import 'package:flutter/material.dart';
import '../../logic/providers/transaction_provider.dart';
import '../../logic/providers/money_formatter_provider.dart';
import '../../models/pending_transaction.dart';

class TransactionDialogSheets {
  static final TransactionDialogSheets _instance =
      TransactionDialogSheets._internal();

  factory TransactionDialogSheets() => _instance;

  TransactionDialogSheets._internal();

  final _transactionProvider = TransactionProvider();

  /// Dialog xác nhận giao dịch ngân hàng
  Future<bool> showBankTransactionConfirmDialog(
    BuildContext context,
    PendingTransaction pending,
  ) async {
    bool isExpense = true;

    final shouldAdd =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Ghi nhận giao dịch?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending.amount > 0
                            ? 'Số tiền: ${MoneyFormatter.formatMoney(pending.amount)}'
                            : 'Số tiền: (không nhận diện được)',
                      ),
                      const SizedBox(height: 12),
                      const Text('Giao dịch này là:'),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: isExpense,
                        onChanged: (v) => setState(() => isExpense = v ?? true),
                        title: const Text('Khoản chi'),
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: isExpense,
                        onChanged: (v) => setState(() => isExpense = v ?? true),
                        title: const Text('Khoản thu'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Bỏ qua'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Thêm lịch sử'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    return shouldAdd && isExpense;
  }

  /// Modal nhập thêm/sửa giao dịch nhanh
  Future<void> showQuickAddSheet(
    BuildContext context,
    String? userId, {
    String? prefillTitle,
    num? prefillAmount,
    required bool isExpenseDefault,
  }) async {
    if (userId == null) return;

    final titleController = TextEditingController(text: prefillTitle ?? '');
    final amountController = TextEditingController(
      text: (prefillAmount != null && prefillAmount > 0)
          ? prefillAmount.toString()
          : '',
    );
    var isExpense = isExpenseDefault;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Thêm lịch sử giao dịch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tên giao dịch',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  hintText: 'Ví dụ: 1200000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      groupValue: isExpense,
                      onChanged: (v) => {},
                      title: const Text('Chi ra'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: isExpense,
                      onChanged: (v) => {},
                      title: const Text('Thu vào'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final rawAmount = MoneyFormatter.normalizeMoneyInput(
                      amountController.text,
                    );
                    final amount = num.tryParse(rawAmount) ?? 0;

                    if (title.isEmpty || amount <= 0) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên và số tiền hợp lệ'),
                        ),
                      );
                      return;
                    }

                    try {
                      await _transactionProvider.createTransaction(
                        userId: userId,
                        title: title,
                        amount: amount,
                        isExpense: isExpense,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Lỗi lưu giao dịch: $e')),
                      );
                    }
                  },
                  child: const Text('Xác nhận'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Modal tạo giao dịch mới với gợi ý tên
  Future<void> showCreateTransactionSheet(
    BuildContext context,
    String? userId,
  ) async {
    if (userId == null) return;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    var isExpense = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _transactionProvider.getTransactionsStream(userId),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              final suggestions = <String>{
                for (final it in items) (it['title'] ?? '').toString().trim(),
              }..removeWhere((e) => e.isEmpty);

              return StatefulBuilder(
                builder: (context, setSheetState) {
                  Future<void> submit() async {
                    final title = titleController.text.trim();
                    final rawAmount = MoneyFormatter.normalizeMoneyInput(
                      amountController.text,
                    );
                    final amount = num.tryParse(rawAmount) ?? 0;

                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên và số tiền hợp lệ'),
                        ),
                      );
                      return;
                    }

                    try {
                      await _transactionProvider.createTransaction(
                        userId: userId,
                        title: title,
                        amount: amount,
                        isExpense: isExpense,
                      );
                      if (context.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi tạo giao dịch: $e')),
                      );
                    }
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Tạo giao dịch mới',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final q = textEditingValue.text.trim().toLowerCase();
                          if (q.isEmpty) return suggestions.take(8);
                          return suggestions
                              .where((s) => s.toLowerCase().contains(q))
                              .take(8);
                        },
                        onSelected: (value) {
                          titleController.text = value;
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              textEditingController.value =
                                  titleController.value;
                              textEditingController.addListener(() {
                                titleController.value =
                                    textEditingController.value;
                              });
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Tên giao dịch',
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Số tiền',
                          hintText: 'Ví dụ: 1200000',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              value: true,
                              groupValue: isExpense,
                              onChanged: (v) =>
                                  setSheetState(() => isExpense = v ?? true),
                              title: const Text('Chi ra'),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              value: false,
                              groupValue: isExpense,
                              onChanged: (v) =>
                                  setSheetState(() => isExpense = v ?? true),
                              title: const Text('Thu vào'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submit,
                          child: const Text('Xác nhận'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

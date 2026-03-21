import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../logic/services/bank_notification_service.dart';
import '../../models/pending_transaction.dart';
import '../../utils/constants.dart';

class BankDialogSheets {
  static final BankDialogSheets _instance = BankDialogSheets._internal();

  factory BankDialogSheets() => _instance;

  BankDialogSheets._internal();

  final _bankService = BankNotificationService();

  /// Dialog chọn ngân hàng liên kết
  Future<void> showSelectBankDialog(BuildContext context) async {
    final current = await _bankService.getLinkedBankScheme();
    if (current != null) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Chọn ngân hàng liên kết'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Mỗi ngân hàng có deep link khác nhau. Chọn ngân hàng bạn dùng (có thể đổi lại sau).',
                ),
                const SizedBox(height: 12),
                ...AppConstants.banks.map(
                  (b) => ListTile(
                    title: Text(b.name),
                    subtitle: Text(b.scheme),
                    onTap: () async {
                      await _bankService.setLinkedBankScheme(b.scheme);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Để sau'),
            ),
          ],
        );
      },
    );
  }

  /// Modal hiển thị thông tin QR đã quét
  Future<void> showQrInfoSheet(
    BuildContext context,
    PendingTransaction pending,
    VoidCallback onChangeBank,
    VoidCallback onOpenBank,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin từ QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Gợi ý tên: ${pending.titleHint}'),
              const SizedBox(height: 6),
              Text(
                pending.amount > 0
                    ? 'Số tiền: ${pending.amount}'
                    : 'Số tiền: (không có)',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onChangeBank,
                      child: const Text('Đổi ngân hàng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onOpenBank,
                      child: const Text('Mở app ngân hàng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mở app ngân hàng
  Future<void> openBankApp(BuildContext context) async {
    final scheme = await _bankService.getLinkedBankScheme();
    if (scheme == null) return;

    final uri = Uri.tryParse(scheme);
    if (uri == null) return;

    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được app ngân hàng với scheme: $scheme (có thể chưa cài app hoặc deep link khác).',
          ),
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../logic/services/bank_notification_service.dart';
import '../../models/pending_transaction.dart';

/// Service quản lý QR scanning
class QrScannerService {
  static final QrScannerService _instance = QrScannerService._internal();

  factory QrScannerService() => _instance;

  QrScannerService._internal();

  final _bankService = BankNotificationService();

  /// Kiểm tra nếu platform hỗ trợ QR scanning
  bool get isQrSupportedOnPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Mở QR scanner modal và trả về dữ liệu đã scan
  Future<String?> scanQrCode(BuildContext context) async {
    String? scanned;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;
                  final raw = barcodes.first.rawValue;
                  if (raw == null || raw.trim().isEmpty) return;
                  scanned = raw.trim();
                  Navigator.of(ctx).pop();
                },
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Đưa mã VietQR vào khung để quét',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return scanned;
  }

  /// Quét QR và trích xuất thông tin giao dịch
  Future<PendingTransaction?> scanAndExtractTransaction(
    BuildContext context,
  ) async {
    final qrCode = await scanQrCode(context);
    if (qrCode == null) return null;

    return _bankService.extractTransactionFromQr(qrCode);
  }
}

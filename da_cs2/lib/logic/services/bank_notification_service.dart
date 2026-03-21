import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../logic/providers/money_formatter_provider.dart';
import '../../models/pending_transaction.dart';

/// Service quản lý bank notifications
class BankNotificationService {
  static final BankNotificationService _instance =
      BankNotificationService._internal();

  factory BankNotificationService() => _instance;

  BankNotificationService._internal();

  /// Lấy bank scheme đã liên kết
  Future<String?> getLinkedBankScheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheme = prefs.getString(AppConstants.linkedBankSchemeKey);
      return (scheme == null || scheme.trim().isEmpty) ? null : scheme.trim();
    } catch (e) {
      print('Error getting linked bank scheme: $e');
      return null;
    }
  }

  /// Lưu bank scheme
  Future<void> setLinkedBankScheme(String? scheme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (scheme == null || scheme.trim().isEmpty) {
        await prefs.remove(AppConstants.linkedBankSchemeKey);
        return;
      }
      await prefs.setString(AppConstants.linkedBankSchemeKey, scheme.trim());
    } catch (e) {
      print('Error setting linked bank scheme: $e');
    }
  }

  /// Parse EMV TLV format từ QR code
  Map<String, String> parseEmvTlv(String payload) {
    final out = <String, String>{};
    var i = 0;
    while (i + 4 <= payload.length) {
      final tag = payload.substring(i, i + 2);
      final lenStr = payload.substring(i + 2, i + 4);
      final len = int.tryParse(lenStr) ?? 0;
      final start = i + 4;
      final end = start + len;
      if (end > payload.length) break;
      out[tag] = payload.substring(start, end);
      i = end;
    }
    return out;
  }

  /// Trích xuất thông tin từ QR code
  PendingTransaction? extractTransactionFromQr(String qrCode) {
    try {
      final tlv = parseEmvTlv(qrCode);
      final amount = num.tryParse((tlv['54'] ?? '').trim()) ?? 0;

      String titleHint = 'Chuyển khoản';
      final additional = tlv['62'];
      if (additional != null && additional.isNotEmpty) {
        final sub = parseEmvTlv(additional);
        final note = (sub['08'] ?? '').trim();
        if (note.isNotEmpty) titleHint = note;
      }

      return PendingTransaction(
        rawPayload: qrCode,
        amount: amount,
        titleHint: titleHint,
      );
    } catch (e) {
      print('Error extracting transaction from QR: $e');
      return null;
    }
  }

  /// Trích xuất thông tin từ bank notification
  PendingTransaction? extractTransactionFromNotification(
    String pkg,
    String body,
  ) {
    try {
      final amount = MoneyFormatter.tryParseAmountFromText(body);
      final titleHint = body.trim().isEmpty
          ? 'Giao dịch ngân hàng'
          : body.split('\n').first.trim();

      return PendingTransaction(
        rawPayload: body,
        amount: amount,
        titleHint: titleHint,
      );
    } catch (e) {
      print('Error extracting transaction from notification: $e');
      return null;
    }
  }
}

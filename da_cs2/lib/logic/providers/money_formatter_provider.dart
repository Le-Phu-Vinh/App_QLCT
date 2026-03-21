import 'package:intl/intl.dart';

/// Provider cung cấp các hàm format tiền tệ
class MoneyFormatter {
  static final _moneyFmt = NumberFormat.decimalPattern('vi_VN');

  /// Chuyển đổi giá trị sang số
  static num asNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  /// Format số thành chuỗi tiền tệ Việt Nam
  static String formatMoney(dynamic value) {
    final n = asNum(value);
    return '${_moneyFmt.format(n)}đ';
  }

  /// Chuẩn hóa input tiền tệ (loại bỏ các ký tự không phải số)
  static String normalizeMoneyInput(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    return s.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Trích xuất số tiền từ văn bản (ví dụ: "1.200.000" -> 1200000)
  static num tryParseAmountFromText(String s) {
    // Tìm số tiền kiểu "1.200.000", "1200000", "1,200,000"
    final re = RegExp(r'(\d[\d\.\, ]{2,}\d)');
    final match = re.firstMatch(s);
    if (match == null) return 0;
    final raw = match.group(1) ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return num.tryParse(digits) ?? 0;
  }
}

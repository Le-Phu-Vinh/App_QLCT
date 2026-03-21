import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'avatar_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lấy instance của Supabase Client
  final supabase = Supabase.instance.client;

  final _moneyFmt = NumberFormat.decimalPattern('vi_VN');
  int _navIndex = 0;
  bool _launchedBank = false;
  _PendingTxn? _pendingTxn;
  _LifecycleObserver? _lifecycleObserver;
  StreamSubscription<dynamic>? _bankNotifSub;
  Uint8List? _avatarBytes;

  static const _bankNotifChannel = EventChannel('bank_notifications');

  bool get _isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _showQrOnThisPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _formatMoney(dynamic v) {
    final n = _asNum(v);
    return '${_moneyFmt.format(n)}đ';
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarString = prefs.getString('user_avatar');
    if (avatarString != null) {
      setState(() {
        _avatarBytes = base64Decode(avatarString);
      });
    }
  }

  Future<void> _saveAvatar(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final avatarString = base64Encode(bytes);
    await prefs.setString('user_avatar', avatarString);
    setState(() {
      _avatarBytes = bytes;
    });
  }

  Future<void> _pickAvatar() async {
    final bytes = await pickAndCropAvatar(context);
    if (bytes != null) {
      await _saveAvatar(bytes);
    }
  }

  // Hàm đăng xuất
  Future<void> _handleSignOut() async {
    await supabase.auth.signOut();
    // Quay lại màn hình đăng nhập (Bạn cần đảm bảo file main.dart có xử lý Auth state)
  }

  Widget _buildNotificationButton(String? userId) {
    if (userId == null) {
      return IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData
            ? snapshot.data!.where((n) => n['is_read'] != true).length
            : 0;

        return Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
          child: IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Thông báo',
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _lifecycleObserver = _LifecycleObserver(onResumed: _onAppResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    // Notification listener chỉ hoạt động trên Android app (không áp dụng Web)
    if (_isAndroidApp) {
      _bankNotifSub = _bankNotifChannel.receiveBroadcastStream().listen((
        event,
      ) {
        if (event is Map) {
          final pkg = (event['package'] ?? '').toString();
          final title = (event['title'] ?? '').toString();
          final text = (event['text'] ?? '').toString();
          final bigText = (event['bigText'] ?? '').toString();
          final merged = [
            title,
            bigText,
            text,
          ].where((e) => e.trim().isNotEmpty).join('\n');
          _handleBankNotification(pkg: pkg, body: merged);
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _bankNotifSub?.cancel();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    super.dispose();
  }

  num _tryParseAmountFromText(String s) {
    // find a money-like number in the text: "1.200.000", "1200000", "1,200,000"
    final re = RegExp(r'(\d[\d\.\, ]{2,}\d)');
    final m = re.firstMatch(s);
    if (m == null) return 0;
    final raw = m.group(1) ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return num.tryParse(digits) ?? 0;
  }

  Future<void> _handleBankNotification({
    required String pkg,
    required String body,
  }) async {
    if (!mounted) return;

    // Only act after we attempted to open bank flow, to reduce noise.
    if (!_launchedBank) return;

    final amount = _tryParseAmountFromText(body);
    final titleHint = body.trim().isEmpty
        ? 'Giao dịch ngân hàng'
        : body.split('\n').first.trim();

    // store for resume flow too
    _pendingTxn = _PendingTxn(
      rawPayload: body,
      amount: amount,
      titleHint: titleHint,
    );

    // If we are already in foreground, ask immediately.
    await _promptAddFromBankNotification(_pendingTxn!);
  }

  Future<void> _promptAddFromBankNotification(_PendingTxn pending) async {
    if (!mounted) return;

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
                            ? 'Số tiền: ${_formatMoney(pending.amount)}'
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

    if (!mounted || !shouldAdd) return;

    await _openQuickAddSheet(
      prefillTitle: pending.titleHint,
      prefillAmount: pending.amount,
      isExpenseDefault: isExpense,
    );
  }

  Future<void> _onAppResumed() async {
    if (!mounted) return;
    if (!_launchedBank || _pendingTxn == null) return;

    _launchedBank = false;
    final pending = _pendingTxn!;
    _pendingTxn = null;
    await _promptAddFromBankNotification(pending);
  }

  String _normalizeMoneyInput(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    // keep digits only; treat separators as formatting
    return s.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Map<String, String> _parseEmvTlv(String payload) {
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

  Future<String?> _getLinkedBankScheme() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('linked_bank_scheme');
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> _setLinkedBankScheme(String? scheme) async {
    final prefs = await SharedPreferences.getInstance();
    if (scheme == null || scheme.trim().isEmpty) {
      await prefs.remove('linked_bank_scheme');
      return;
    }
    await prefs.setString('linked_bank_scheme', scheme.trim());
  }

  Future<void> _ensureLinkedBankSelected() async {
    final current = await _getLinkedBankScheme();
    if (current != null) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        const banks = <({String name, String scheme})>[
          (name: 'MB Bank', scheme: 'mbbank://'),
          (name: 'Vietcombank', scheme: 'vcb://'),
          (name: 'Techcombank', scheme: 'tcb://'),
          (name: 'ACB', scheme: 'acb://'),
          (name: 'BIDV', scheme: 'bidvsmartbanking://'),
        ];

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
                ...banks.map(
                  (b) => ListTile(
                    title: Text(b.name),
                    subtitle: Text(b.scheme),
                    onTap: () async {
                      await _setLinkedBankScheme(b.scheme);
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

  Future<_PendingTxn?> _scanQrAndExtractInfo() async {
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

    if (scanned == null) return null;

    final tlv = _parseEmvTlv(scanned!);
    final amount = num.tryParse((tlv['54'] ?? '').trim()) ?? 0;

    String titleHint = 'Chuyển khoản';
    final additional = tlv['62'];
    if (additional != null && additional.isNotEmpty) {
      final sub = _parseEmvTlv(additional);
      final note = (sub['08'] ?? '').trim();
      if (note.isNotEmpty) titleHint = note;
    }

    return _PendingTxn(
      rawPayload: scanned!,
      amount: amount,
      titleHint: titleHint,
    );
  }

  Future<void> _openLinkedBankApp(_PendingTxn pending) async {
    await _ensureLinkedBankSelected();
    final scheme = await _getLinkedBankScheme();
    if (scheme == null) return;

    final uri = Uri.tryParse(scheme);
    if (uri == null) return;

    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không mở được app ngân hàng với scheme: $scheme (có thể chưa cài app hoặc deep link khác).',
          ),
        ),
      );
      return;
    }

    _pendingTxn = pending;
    _launchedBank = true;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleQrScanFlow() async {
    final pending = await _scanQrAndExtractInfo();
    if (pending == null) return;
    if (!mounted) return;

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
                    ? 'Số tiền: ${_formatMoney(pending.amount)}'
                    : 'Số tiền: (không có)',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _setLinkedBankScheme(null);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _ensureLinkedBankSelected();
                      },
                      child: const Text('Đổi ngân hàng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _openLinkedBankApp(pending);
                      },
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

  Future<void> _createTransaction({
    required String userId,
    required String title,
    required num amount,
    required bool isExpense,
  }) async {
    final signedAmount = isExpense ? -amount.abs() : amount.abs();

    await supabase.from('transactions').insert({
      'user_id': userId,
      'title': title,
      'amount': signedAmount,
    });

    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'type': 'transaction',
        'title': title,
        'body': '${isExpense ? "Chi" : "Thu"}: ${_formatMoney(amount.abs())}',
        'is_read': false,
      });
    } catch (_) {
      // Bảng notifications có thể chưa tồn tại
    }

    // Update profile totals so summary cards refresh
    final profile = await supabase
        .from('profiles')
        .select('balance, expense, income')
        .eq('id', userId)
        .single();

    final curBalance = _asNum(profile['balance']);
    final curExpense = _asNum(profile['expense']);
    final curIncome = _asNum(profile['income']);

    final nextBalance = curBalance + signedAmount;
    final nextExpense = isExpense ? (curExpense + amount.abs()) : curExpense;
    final nextIncome = isExpense ? curIncome : (curIncome + amount.abs());

    await supabase
        .from('profiles')
        .update({
          'balance': nextBalance,
          'expense': nextExpense,
          'income': nextIncome,
        })
        .eq('id', userId);
  }

  Future<void> _openQuickAddSheet({
    String? prefillTitle,
    num? prefillAmount,
    required bool isExpenseDefault,
  }) async {
    final userId = supabase.auth.currentUser?.id;
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
                      onChanged: (v) => setState(() => isExpense = v ?? true),
                      title: const Text('Chi ra'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: isExpense,
                      onChanged: (v) => setState(() => isExpense = v ?? true),
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
                    final rawAmount = _normalizeMoneyInput(
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
                      await _createTransaction(
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

  Future<void> _openCreateTransactionSheet() async {
    final userId = supabase.auth.currentUser?.id;
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
            stream: _transactionsStream(userId),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              final suggestions = <String>{
                for (final it in items) (it['title'] ?? '').toString().trim(),
              }..removeWhere((e) => e.isEmpty);

              return StatefulBuilder(
                builder: (context, setSheetState) {
                  Future<void> submit() async {
                    final title = titleController.text.trim();
                    final rawAmount = _normalizeMoneyInput(
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
                      await _createTransaction(
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
                              // keep a single controller for reading submit values
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

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin User đang đăng nhập
    final user = supabase.auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: _pickAvatar,
          icon: _avatarBytes != null
              ? CircleAvatar(
                  backgroundImage: MemoryImage(_avatarBytes!),
                  radius: 15,
                )
              : const Icon(Icons.account_circle, size: 30),
        ),
        actions: [
          _buildNotificationButton(user?.id),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
          IconButton(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout), // Đổi icon sang logout cho rõ ràng
          ),
        ],
      ),
      // Dùng Stream để lắng nghe thay đổi từ bảng 'profiles' trong Supabase
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('id', user?.id ?? '')
            .limit(1),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("Không tìm thấy dữ liệu người dùng"),
            );
          }

          // Supabase Stream trả về một danh sách các dòng, chúng ta lấy dòng đầu tiên
          final userData = snapshot.data![0];
          String username = userData['username'] ?? "Người dùng";
          final balance = _asNum(userData['balance']);
          final expense = _asNum(userData['expense']);
          final income = _asNum(userData['income']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chào $username",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                _buildMainCard(balance: balance, userId: user?.id),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _buildSubCard(
                      "Chi tiêu",
                      _formatMoney(expense),
                      Colors.red,
                    ),
                    const SizedBox(width: 15),
                    _buildSubCard(
                      "Thu nhập",
                      _formatMoney(income),
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  "Lịch sử giao dịch gần đây",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Phần lịch sử giao dịch thật từ bảng 'transactions'
                _buildRealTransactionList(user?.id),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTransactionSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Home'),
      if (_showQrOnThisPlatform)
        const BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Quét mã',
        ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tôi'),
    ];

    // tránh crash khi số tab thay đổi theo platform
    final int safeIndex;
    if (items.isEmpty) {
      safeIndex = 0;
    } else {
      final maxIndex = items.length - 1;
      safeIndex = _navIndex < 0
          ? 0
          : (_navIndex > maxIndex ? maxIndex : _navIndex);
    }
    if (safeIndex != _navIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _navIndex = safeIndex);
      });
    }

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: (idx) async {
        // tab "Tôi" (cuối cùng) → chuyển sang màn hình tài khoản
        if (idx == items.length - 1) {
          setState(() => _navIndex = idx);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
          return;
        }
        if (_showQrOnThisPlatform && idx == 1) {
          await _handleQrScanFlow();
          return;
        }
        setState(() => _navIndex = idx);
      },
      items: items,
    );
  }

  Stream<List<Map<String, dynamic>>> _transactionsStream(String? userId) {
    return supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false);
  }

  // Widget hiển thị danh sách giao dịch thật từ Database
  Widget _buildRealTransactionList(String? userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _transactionsStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: Text("Chưa có giao dịch nào")),
          );
        }

        return Column(
          children: snapshot.data!.map((item) {
            final title = (item['title'] ?? '').toString().trim();
            final amount = _asNum(item['amount']);
            return _buildTransactionItem(
              title.isEmpty ? 'Giao dịch' : title,
              _formatMoney(amount),
            );
          }).toList(),
        );
      },
    );
  }

  // --- Các Widget giao dịch giữ nguyên từ bản cũ ---
  Widget _buildMainCard({required num balance, required String? userId}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tổng số dư: ${_formatMoney(balance)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildExpensePieChart(userId),
        ],
      ),
    );
  }

  Widget _buildExpensePieChart(String? userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _transactionsStream(userId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];

        final Map<String, double> totals = {};
        for (final item in items) {
          final amount = _asNum(item['amount']).toDouble();
          if (amount >= 0) continue; // chỉ lấy chi tiêu
          final title = (item['title'] ?? '').toString().trim();
          final key = title.isEmpty ? 'Khác' : title;
          totals[key] = (totals[key] ?? 0) + amount.abs();
        }

        if (totals.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Chưa có dữ liệu chi tiêu để vẽ biểu đồ'),
            ),
          );
        }

        final entries = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        const maxSlices = 6;
        final visible = entries.take(maxSlices).toList();
        final rest = entries
            .skip(maxSlices)
            .fold<double>(0, (sum, e) => sum + e.value);
        if (rest > 0) visible.add(MapEntry('Khác', rest));

        final colors = <Color>[
          Colors.blue,
          Colors.red,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.brown,
        ];

        final total = visible.fold<double>(0, (sum, e) => sum + e.value);
        final sections = <PieChartSectionData>[];
        for (var i = 0; i < visible.length; i++) {
          final e = visible[i];
          final pct = total == 0 ? 0 : (e.value / total) * 100;
          sections.add(
            PieChartSectionData(
              value: e.value,
              color: colors[i % colors.length],
              radius: 70,
              title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...visible.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final color = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatMoney(e.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSubCard(String title, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              amount,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PendingTxn {
  _PendingTxn({
    required this.rawPayload,
    required this.amount,
    required this.titleHint,
  });

  final String rawPayload;
  final num amount;
  final String titleHint;
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({required this.onResumed}) {
    // no-op
  }

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

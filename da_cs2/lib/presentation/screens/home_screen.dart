import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../logic/providers/avatar_provider.dart';
import '../../logic/providers/profile_provider.dart';
import '../../logic/providers/money_formatter_provider.dart';
import '../../logic/services/auth_service.dart';
import '../../logic/services/bank_notification_service.dart';
import '../../logic/services/notification_listener_service.dart';
import '../../logic/services/qr_scanner_service.dart';
import '../../logic/services/budget_alert_service.dart';
import '../../models/lifecycle_observer.dart';
import '../../models/pending_transaction.dart';
import '../../presentation/widgets/notification_button.dart';
import '../../presentation/widgets/main_balance_card.dart';
import '../../presentation/widgets/summary_card.dart';
import '../../presentation/widgets/transactions_list.dart';
import '../../presentation/widgets/home_bottom_nav.dart';
import 'all_transactions_screen.dart';
import '../../presentation/widgets/transaction_dialog_sheets.dart';
import '../../presentation/widgets/bank_dialog_sheets.dart';
import '../utils/avatar_picker.dart';
import 'budget_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Providers & Services
  final _authService = AuthService();
  final _profileProvider = ProfileProvider();
  final _avatarProvider = AvatarProvider();
  final _bankService = BankNotificationService();
  final _notifListener = NotificationListenerService();
  final _qrService = QrScannerService();
  final _transactionDialogs = TransactionDialogSheets();
  final _bankDialogs = BankDialogSheets();
  final _budgetAlertService = BudgetAlertService();

  // State
  int _navIndex = 0;
  bool _launchedBank = false;
  PendingTransaction? _pendingTxn;
  LifecycleObserver? _lifecycleObserver;
  Uint8List? _avatarBytes;

  bool get _isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Khởi tạo ứng dụng: tải avatar, nghe notifications
  Future<void> _initializeApp() async {
    // Tải avatar
    await _avatarProvider.loadAvatar();
    if (mounted) {
      setState(() {
        _avatarBytes = _avatarProvider.avatarBytes;
      });
    }

    // Nghe lifecycle events
    _lifecycleObserver = LifecycleObserver(onResumed: _onAppResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    // Nghe bank notifications (chỉ Android app)
    if (_isAndroidApp) {
      _notifListener.startListening(_handleBankNotification);
    }

    // Thiết lập kiểm tra budget alerts hàng ngày
    _setupBudgetAlertTimer();
  }

  /// Thiết lập timer kiểm tra budget alerts hàng ngày
  void _setupBudgetAlertTimer() {
    // Kiểm tra ngay lập tức
    final userId = _authService.getCurrentUser()?.id;
    if (userId != null) {
      _budgetAlertService.checkAndSendAlerts(userId);
    }

    // Thiết lập timer hàng ngày (24 giờ)
    // Trong production, nên dùng work manager hoặc background task
    Future.delayed(const Duration(hours: 24), () {
      if (mounted) {
        _setupBudgetAlertTimer();
      }
    });
  }

  @override
  void dispose() {
    _notifListener.stopListening();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    super.dispose();
  }

  /// Xử lý bank notification khi app ở background/foreground
  Future<void> _handleBankNotification(String pkg, String body) async {
    if (!mounted || !_launchedBank) return;

    _pendingTxn = _bankService.extractTransactionFromNotification(pkg, body);
    if (_pendingTxn != null) {
      await _promptAddFromBankNotification(_pendingTxn!);
    }
  }

  /// Hiển thị dialog xác nhận giao dịch từ bank notification
  Future<void> _promptAddFromBankNotification(
    PendingTransaction pending,
  ) async {
    if (!mounted) return;

    final isExpense = await _transactionDialogs
        .showBankTransactionConfirmDialog(context, pending);

    if (!mounted || !isExpense) return;

    await _transactionDialogs.showQuickAddSheet(
      context,
      _authService.getCurrentUser()?.id,
      prefillTitle: pending.titleHint,
      prefillAmount: pending.amount,
      isExpenseDefault: true,
    );
  }

  /// Callback khi app resume
  Future<void> _onAppResumed() async {
    if (!mounted || !_launchedBank || _pendingTxn == null) return;

    _launchedBank = false;
    final pending = _pendingTxn!;
    _pendingTxn = null;
    await _promptAddFromBankNotification(pending);
  }

  /// Xử lý QR scan flow
  Future<void> _handleQrScanFlow() async {
    final pending = await _qrService.scanAndExtractTransaction(context);
    if (pending == null || !mounted) return;

    await _bankDialogs.showQrInfoSheet(
      context,
      pending,
      () async {
        await _bankService.setLinkedBankScheme(null);
        if (mounted) Navigator.of(context).pop();
        await _bankDialogs.showSelectBankDialog(context);
      },
      () async {
        if (mounted) Navigator.of(context).pop();
        _pendingTxn = pending;
        _launchedBank = true;
        await _bankDialogs.openBankApp(context);
      },
    );
  }

  /// Xử lý chọn ảnh avatar
  Future<void> _pickAvatar() async {
    final bytes = await pickAndCropAvatar(context);
    if (bytes != null) {
      await _avatarProvider.saveAvatar(bytes);
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
        });
      }
    }
  }

  /// Xử lý đăng xuất
  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
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
          NotificationButton(userId: user?.id),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
          IconButton(onPressed: _handleSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _profileProvider.getProfileStream(user?.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("Không tìm thấy dữ liệu người dùng"),
              );
            }

            final userData = snapshot.data![0];
            final username = userData['username'] ?? "Người dùng";
            final balance = MoneyFormatter.asNum(userData['balance']);
            final expense = MoneyFormatter.asNum(userData['expense']);
            final income = MoneyFormatter.asNum(userData['income']);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                  MainBalanceCard(balance: balance, userId: user?.id),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SummaryCard(
                        title: "Chi tiêu",
                        amount: MoneyFormatter.formatMoney(expense),
                        color: Colors.red,
                      ),
                      const SizedBox(width: 15),
                      SummaryCard(
                        title: "Thu nhập",
                        amount: MoneyFormatter.formatMoney(income),
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BudgetSettingsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Theme.of(context).primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cài đặt ngân sách',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Đặt mục tiêu chi tiêu theo tháng',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Lịch sử giao dịch gần đây",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AllTransactionsScreen(),
                            ),
                          );
                        },
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TransactionsList(userId: user?.id, limit: 5),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: HomeBottomNav(
        currentIndex: _navIndex,
        onIndexChanged: (idx) {
          setState(() => _navIndex = idx);
        },
        onQrScan: _handleQrScanFlow,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _transactionDialogs.showCreateTransactionSheet(
          context,
          _authService.getCurrentUser()?.id,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../../logic/services/qr_scanner_service.dart';

class HomeBottomNav extends StatefulWidget {
  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onQrScan,
  });

  final int currentIndex;
  final Function(int) onIndexChanged;
  final VoidCallback onQrScan;

  @override
  State<HomeBottomNav> createState() => _HomeBottomNavState();
}

class _HomeBottomNavState extends State<HomeBottomNav> {
  final _qrService = QrScannerService();

  bool get _showQrOnThisPlatform => _qrService.isQrSupportedOnPlatform;

  @override
  Widget build(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Home'),
      if (_showQrOnThisPlatform)
        const BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Quét mã',
        ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tôi'),
    ];

    // Đảm bảo currentIndex không vượt quá số lượng items
    final int safeIndex;
    if (items.isEmpty) {
      safeIndex = 0;
    } else {
      final maxIndex = items.length - 1;
      safeIndex = widget.currentIndex < 0
          ? 0
          : (widget.currentIndex > maxIndex ? maxIndex : widget.currentIndex);
    }

    if (safeIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onIndexChanged(safeIndex);
      });
    }

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: (idx) async {
        // Tab "Tôi" (cuối cùng) → chuyển sang màn hình tài khoản
        if (idx == items.length - 1) {
          widget.onIndexChanged(idx);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
          return;
        }

        // Tab "Quét mã"
        if (_showQrOnThisPlatform && idx == 1) {
          widget.onQrScan();
          return;
        }

        widget.onIndexChanged(idx);
      },
      items: items,
    );
  }
}

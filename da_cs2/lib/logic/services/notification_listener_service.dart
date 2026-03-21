import 'dart:async';
import '../../utils/constants.dart';

/// Service lắng nghe thông báo từ native layer
class NotificationListenerService {
  static final NotificationListenerService _instance =
      NotificationListenerService._internal();

  factory NotificationListenerService() => _instance;

  NotificationListenerService._internal();

  StreamSubscription<dynamic>? _subscription;

  /// Bắt đầu lắng nghe bank notifications
  void startListening(Function(String pkg, String body) onNotification) {
    if (_subscription != null) return;

    _subscription = AppConstants.bankEventChannel
        .receiveBroadcastStream()
        .listen(
          (event) {
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
              onNotification(pkg, merged);
            }
          },
          onError: (error) {
            print('Error listening to bank notifications: $error');
          },
        );
  }

  /// Dừng lắng nghe
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}

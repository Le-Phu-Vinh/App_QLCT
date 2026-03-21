import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> _markAllAsRead() async {
    final userId = _authService.getCurrentUser()?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  /// Xoá thông báo
  Future<void> _deleteNotification(String notifId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notifId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUser()?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: userId == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('notifications')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa thiết lập bảng thông báo.\nVui lòng chạy SQL trong Supabase Dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('Chưa có thông báo nào'),
                      ],
                    ),
                  );
                }

                final hasUnread = items.any(
                  (e) => (e['is_read'] ?? true) == false,
                );

                return Column(
                  children: [
                    if (hasUnread)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _markAllAsRead,
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Đánh dấu đã đọc tất cả'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final notif = items[i];
                          final type = (notif['type'] ?? 'system').toString();
                          final title = (notif['title'] ?? '').toString();
                          final body = (notif['body'] ?? '').toString();
                          final createdAt = notif['created_at'];
                          final isRead = notif['is_read'] == true;

                          final icon = type == 'transaction'
                              ? Icons.receipt_long
                              : Icons.info_outline;
                          final iconColor = type == 'transaction'
                              ? Colors.blue
                              : Colors.orange;

                          return Dismissible(
                            key: ValueKey(notif['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) =>
                                _deleteNotification(notif['id']),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withOpacity(0.2),
                                child: Icon(icon, color: iconColor),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(body, maxLines: 2),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dateFmt.format(DateTime.parse(createdAt)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: !isRead
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

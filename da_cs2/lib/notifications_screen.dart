import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Màn hình hiển thị thông báo từ hệ thống và giao dịch mới.
/// Yêu cầu bảng `notifications` trong Supabase (xem SQL trong comment).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;

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
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
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
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chưa có thông báo nào'),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    if (items.any((e) => (e['is_read'] ?? true) == false))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              await _markAllAsRead();
                            },
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Đánh dấu đã đọc tất cả'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final n = items[i];
                          final type = (n['type'] ?? 'system').toString();
                          final title = (n['title'] ?? '').toString();
                          final body = (n['body'] ?? '').toString();
                          final createdAt = n['created_at'];
                          final isRead = n['is_read'] == true;

                          final icon = type == 'transaction'
                              ? Icons.receipt_long
                              : Icons.info_outline;
                          final iconColor = type == 'transaction'
                              ? Colors.blue
                              : Colors.orange;

                          return Dismissible(
                            key: ValueKey(n['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              try {
                                await _supabase
                                    .from('notifications')
                                    .delete()
                                    .eq('id', n['id']);
                              } catch (_) {}
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withOpacity(0.2),
                                child: Icon(icon, color: iconColor),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: body.isNotEmpty
                                  ? Text(
                                      body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: createdAt != null
                                  ? Text(
                                      _dateFmt.format(DateTime.parse(createdAt.toString())),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                if (!isRead) {
                                  try {
                                    await _supabase
                                        .from('notifications')
                                        .update({'is_read': true})
                                        .eq('id', n['id']);
                                  } catch (_) {}
                                }
                              },
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

/*
  SQL tạo bảng notifications trong Supabase (SQL Editor):
  ----------------------------------------
  create table if not exists notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    type text not null check (type in ('transaction', 'system')),
    title text not null,
    body text,
    ref_id text,
    created_at timestamptz default now(),
    is_read boolean default false
  );

  alter table notifications enable row level security;

  create policy "Users manage own notifications"
    on notifications for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

  create index if not exists idx_notifications_user_read
    on notifications(user_id, is_read) where is_read = false;
  ----------------------------------------
*/

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/notifications_screen.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key, required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId!),
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
}

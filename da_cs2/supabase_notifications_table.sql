-- Chạy SQL này trong Supabase Dashboard > SQL Editor để tạo bảng thông báo

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

drop policy if exists "Users manage own notifications" on notifications;
create policy "Users manage own notifications"
  on notifications for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_notifications_user_read
  on notifications(user_id, is_read) where is_read = false;

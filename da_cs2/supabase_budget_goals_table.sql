-- Chạy SQL này trong Supabase Dashboard > SQL Editor để tạo bảng budget_goals

create table if not exists budget_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  category text not null,
  target_amount numeric not null check (target_amount > 0),
  month integer not null check (month >= 1 and month <= 12),
  year integer not null check (year >= 2020),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table budget_goals enable row level security;

drop policy if exists "Users manage own budget goals" on budget_goals;
create policy "Users manage own budget goals"
  on budget_goals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_budget_goals_user_month_year
  on budget_goals(user_id, month, year);

-- Trigger để cập nhật updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language 'plpgsql';

create trigger update_budget_goals_updated_at
  before update on budget_goals
  for each row execute procedure update_updated_at_column();
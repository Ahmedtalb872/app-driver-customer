-- Real backing for the admin dashboard's "الدعم والشكاوى" section (until
-- now a ComingSoonScreen placeholder - see AdminSupportScreen) and for the
-- customer app's "محادثة مباشرة" support button (until now just a snackbar
-- that never actually opened anything - see SupportScreen). One flat
-- ticket + message thread per user, closer to a live-chat widget than a
-- classic multi-ticket helpdesk: a user has at most one open/in_progress
-- thread at a time (support_ticket_repository.dart enforces this by
-- reusing any existing non-closed ticket instead of always creating a new
-- one), and admins reply from the same thread.

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  subject text not null default 'محادثة دعم',
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_tickets_user_id_idx
  on public.support_tickets (user_id);
create index if not exists support_tickets_status_updated_idx
  on public.support_tickets (status, updated_at desc);

create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  is_admin_reply boolean not null default false,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists support_ticket_messages_ticket_id_idx
  on public.support_ticket_messages (ticket_id, created_at);

alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;

drop policy if exists "Support tickets viewable by owner or admin" on public.support_tickets;
create policy "Support tickets viewable by owner or admin"
  on public.support_tickets for select
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Support tickets insertable by owner" on public.support_tickets;
create policy "Support tickets insertable by owner"
  on public.support_tickets for insert
  with check (auth.uid() = user_id);

-- Status is the only field an admin changes directly on the ticket row
-- itself (everything else - new activity's updated_at/reopen-on-reply - is
-- handled by the trigger below); a ticket owner never updates their own
-- ticket row directly, only ever via inserting a new message.
drop policy if exists "Support tickets updatable by admin" on public.support_tickets;
create policy "Support tickets updatable by admin"
  on public.support_tickets for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Support ticket messages viewable by ticket owner or admin" on public.support_ticket_messages;
create policy "Support ticket messages viewable by ticket owner or admin"
  on public.support_ticket_messages for select
  using (
    exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and (t.user_id = auth.uid() or public.is_admin())
    )
  );

-- is_admin_reply must match the sender's actual role at insert time (not
-- client-supplied trust) - otherwise any customer could mark their own
-- message as an official admin reply.
drop policy if exists "Support ticket messages insertable by ticket owner or admin" on public.support_ticket_messages;
create policy "Support ticket messages insertable by ticket owner or admin"
  on public.support_ticket_messages for insert
  with check (
    sender_id = auth.uid()
    and is_admin_reply = public.is_admin()
    and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and (t.user_id = auth.uid() or public.is_admin())
    )
  );

-- Keeps the ticket row in sync with new activity so the admin list can
-- sort by freshest thread: a customer message reopens a resolved/closed
-- ticket (they're still talking to someone), an admin reply on a brand
-- new ticket moves it from open into in_progress.
create or replace function public.touch_support_ticket_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_admin_reply then
    update public.support_tickets
      set updated_at = now(),
          status = case when status = 'open' then 'in_progress' else status end
      where id = new.ticket_id;
  else
    update public.support_tickets
      set updated_at = now(),
          status = case when status in ('resolved', 'closed') then 'open' else status end
      where id = new.ticket_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_touch_support_ticket_on_message on public.support_ticket_messages;
create trigger trg_touch_support_ticket_on_message
  after insert on public.support_ticket_messages
  for each row execute function public.touch_support_ticket_on_message();

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

-- Realtime only pushes changes for tables added to this publication - a
-- brand new table needs adding explicitly (see call_signals/trips for the
-- same pattern).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_ticket_messages'
  ) then
    alter publication supabase_realtime add table public.support_ticket_messages;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_tickets'
  ) then
    alter publication supabase_realtime add table public.support_tickets;
  end if;
end $$;

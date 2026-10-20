-- =====================================================================
-- Nauka indywidualna — przydziały materiału (uruchom raz w SQL Editor)
-- Nauczyciel zapisuje plan dla ucznia ze swojej klasy; uczeń tylko go czyta.
-- =====================================================================
create table if not exists public.assignments (
  teacher_id uuid not null references public.teachers(user_id) on delete cascade,
  email      text not null check (email = lower(email) and position('@' in email) > 1),
  data       jsonb not null check (pg_column_size(data) < 500000),
  updated_at timestamptz not null default now(),
  primary key (teacher_id, email)
);
create index if not exists assignments_email_idx on public.assignments(email);
alter table public.assignments enable row level security;

drop policy if exists assignments_teacher on public.assignments;
create policy assignments_teacher on public.assignments for all to authenticated
  using (teacher_id = auth.uid() and public.is_active_teacher())
  with check (teacher_id = auth.uid() and public.is_active_teacher() and exists (
    select 1 from public.class_members m join public.classes c on c.id = m.class_id
    where m.email = assignments.email and c.teacher_id = auth.uid()));
drop policy if exists assignments_student on public.assignments;
create policy assignments_student on public.assignments for select to authenticated
  using (email = public.my_email());

revoke all on public.assignments from anon;
grant select, insert, update, delete on public.assignments to authenticated;

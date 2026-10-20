-- =====================================================================
--  Matura Informatyka — Trener: konta, klasy i postęp uczniów
--  Uruchom raz w Supabase: SQL Editor → New query → wklej → Run.
--  Skrypt można uruchomić ponownie (jest idempotentny).
-- =====================================================================

-- ---------- tabele ----------------------------------------------------

-- Nauczyciele (licencja: active). Administrator zatwierdza nowych nauczycieli.
create table if not exists public.teachers (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text not null unique check (email = lower(email)),
  name       text,
  school     text,
  active     boolean not null default false,
  is_admin   boolean not null default false,
  created_at timestamptz not null default now()
);

-- Klasy / grupy nauczyciela (opcjonalnie powiązane z kursem Google Classroom).
create table if not exists public.classes (
  id                  uuid primary key default gen_random_uuid(),
  teacher_id          uuid not null references public.teachers(user_id) on delete cascade,
  name                text not null check (length(name) between 1 and 120),
  classroom_course_id text,
  created_at          timestamptz not null default now(),
  unique (teacher_id, classroom_course_id)
);

-- Lista dozwolonych uczniów (po adresie e-mail konta Google).
create table if not exists public.class_members (
  class_id uuid not null references public.classes(id) on delete cascade,
  email    text not null check (email = lower(email) and position('@' in email) > 1),
  name     text,
  added_at timestamptz not null default now(),
  primary key (class_id, email)
);
create index if not exists class_members_email_idx on public.class_members(email);

-- Profil zalogowanej osoby (e-mail z tokenu Google, ostatnia aktywność).
create table if not exists public.profiles (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  email     text not null check (email = lower(email)),
  name      text,
  last_seen timestamptz not null default now()
);
create index if not exists profiles_email_idx on public.profiles(email);

-- Postęp: jeden wiersz na klucz (kurs Python, kurs SQL, odpowiedzi, …).
create table if not exists public.progress (
  user_id    uuid not null references auth.users(id) on delete cascade,
  key        text not null check (key ~ '^mi-[a-z0-9-]{1,40}$'),
  data       jsonb not null check (pg_column_size(data) < 2000000),
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- ---------- funkcje pomocnicze (security definer, bez rekursji RLS) ----

create or replace function public.my_email() returns text
language sql stable set search_path = '' as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.teachers t
                 where t.user_id = auth.uid() and t.is_admin and t.active)
$$;

create or replace function public.is_active_teacher() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.teachers t
                 where t.user_id = auth.uid() and t.active)
$$;

-- Czy zalogowana osoba może korzystać z aplikacji?
create or replace function public.has_access() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    public.is_active_teacher()
    or exists (
      select 1
      from public.class_members m
      join public.classes  c on c.id = m.class_id
      join public.teachers t on t.user_id = c.teacher_id and t.active
      where m.email = public.my_email()
    )
  )
$$;

-- Czy zalogowany nauczyciel uczy danego użytkownika?
create or replace function public.teaches(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    join public.class_members m on m.email = p.email
    join public.classes c on c.id = m.class_id
    where p.user_id = uid and c.teacher_id = auth.uid()
  ) and public.is_active_teacher()
$$;

-- Informacja o koncie dla aplikacji (jedno zapytanie po zalogowaniu).
create or replace function public.whoami() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'email', public.my_email(),
    'access', public.has_access(),
    'teacher', (select to_jsonb(t) - 'user_id' from public.teachers t where t.user_id = auth.uid()),
    'classes', coalesce((
      select jsonb_agg(distinct c.name)
      from public.class_members m join public.classes c on c.id = m.class_id
      where m.email = public.my_email()), '[]'::jsonb)
  )
$$;

-- Zgłoszenie nauczyciela (konto nieaktywne do zatwierdzenia przez administratora).
create or replace function public.request_teacher(p_name text, p_school text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.teachers(user_id, email, name, school)
  values (auth.uid(), public.my_email(), left(p_name, 120), left(p_school, 160))
  on conflict (user_id) do update set name = excluded.name, school = excluded.school;
end $$;

-- ---------- RLS --------------------------------------------------------

alter table public.teachers      enable row level security;
alter table public.classes       enable row level security;
alter table public.class_members enable row level security;
alter table public.profiles      enable row level security;
alter table public.progress      enable row level security;

-- teachers
drop policy if exists teachers_select on public.teachers;
create policy teachers_select on public.teachers for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists teachers_admin on public.teachers;
create policy teachers_admin on public.teachers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- classes
drop policy if exists classes_teacher on public.classes;
create policy classes_teacher on public.classes for all to authenticated
  using (teacher_id = auth.uid() and public.is_active_teacher())
  with check (teacher_id = auth.uid() and public.is_active_teacher());
drop policy if exists classes_admin_read on public.classes;
create policy classes_admin_read on public.classes for select to authenticated
  using (public.is_admin());

-- class_members
drop policy if exists members_teacher on public.class_members;
create policy members_teacher on public.class_members for all to authenticated
  using (exists (select 1 from public.classes c where c.id = class_id and c.teacher_id = auth.uid())
         and public.is_active_teacher())
  with check (exists (select 1 from public.classes c where c.id = class_id and c.teacher_id = auth.uid())
              and public.is_active_teacher());
drop policy if exists members_self on public.class_members;
create policy members_self on public.class_members for select to authenticated
  using (email = public.my_email());

-- profiles
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and email = public.my_email());
drop policy if exists profiles_teacher on public.profiles;
create policy profiles_teacher on public.profiles for select to authenticated
  using (public.teaches(user_id) or public.is_admin());

-- progress
drop policy if exists progress_self on public.progress;
create policy progress_self on public.progress for all to authenticated
  using (user_id = auth.uid() and public.has_access())
  with check (user_id = auth.uid() and public.has_access());
drop policy if exists progress_teacher on public.progress;
create policy progress_teacher on public.progress for select to authenticated
  using (public.teaches(user_id));

-- ---------- uprawnienia ----------------------------------------------
revoke all on public.teachers, public.classes, public.class_members, public.profiles, public.progress from anon;
grant select, insert, update, delete on public.teachers, public.classes, public.class_members, public.profiles, public.progress to authenticated;
grant execute on function public.has_access(), public.whoami(), public.request_teacher(text, text),
                          public.my_email(), public.is_admin(), public.is_active_teacher(), public.teaches(uuid)
  to authenticated;
revoke execute on function public.has_access(), public.whoami(), public.request_teacher(text, text),
                           public.teaches(uuid) from anon, public;
grant execute on function public.has_access() to anon;  -- bramka: dla anonima zwraca false

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

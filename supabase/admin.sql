-- =====================================================================
--  Jednorazowo: nadaj sobie rolę administratora i nauczyciela.
--  1) Najpierw zaloguj się raz do aplikacji swoim kontem Google
--     (strona pokaże „brak dostępu” — to normalne).
--  2) Wpisz poniżej swój adres e-mail i uruchom w SQL Editor.
-- =====================================================================
insert into public.teachers (user_id, email, name, active, is_admin)
select id, lower(email), 'Administrator', true, true
from auth.users
where lower(email) = lower('WPISZ_SWOJ_EMAIL@2lo.sandomierz.pl')
on conflict (user_id) do update set active = true, is_admin = true;

select email, active, is_admin from public.teachers;

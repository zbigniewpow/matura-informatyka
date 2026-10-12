# Konta uczniów — wdrożenie (Matura Informatyka · Trener)

## Jak to działa

- **Logowanie:** konto Google przez Supabase Auth. Uczeń wchodzi tylko wtedy, gdy jego e-mail jest na liście klasy aktywnego nauczyciela.
- **Bramka (Netlify Edge Function `gate.js`):** plik aplikacji (`index.html`) jest wysyłany tylko zalogowanym osobom z dostępem. Pozostali trafiają na `login.html`.
- **Postęp:**
  - Aplikacja zapisuje postęp lokalnie i synchronizuje go z tabelą `progress`: kursy Python i SQL, Od zera, Ćwiczenia, arkusze, sprawdziany, ostatnie miejsce i projekty w edytorze Python.
  - Zmiany z kilku urządzeń są scalane, zaliczone zadania nigdy nie znikają.
  - Bez internetu zapis czeka i wysyła się po powrocie sieci.
- **Wspólny komputer:** po wylogowaniu postęp ucznia jest usuwany z przeglądarki. Kolejny uczeń nie zobaczy ani nie przejmie cudzych wyników.
- **Panel nauczyciela:**
  - klasy i dodawanie uczniów po adresach e-mail: wklejka (np. skopiowana z Gmaila albo Classroom) lub plik CSV z konsoli administratora Google;
  - tabela postępów i eksport CSV.
- **Administrator** zatwierdza zgłoszenia nowych nauczycieli (przygotowanie pod inne szkoły).
- **Bezpieczeństwo:**
  - Reguły RLS w bazie: uczeń widzi i zapisuje tylko swój postęp; nauczyciel widzi tylko uczniów swoich klas i nie może zmieniać ich postępu.
  - Nieaktywny nauczyciel nie daje dostępu nikomu.

## Pliki paczki

```
netlify.toml                      — katalog publikacji: public/
netlify/edge-functions/gate.js    — bramka
public/index.html                 — aplikacja (z logowaniem)
public/login.html                 — strona logowania
public/robots.txt                 — blokada indeksowania
supabase/schema.sql               — tabele, funkcje i reguły dostępu
supabase/admin.sql                — nadanie sobie roli administratora
```

## Kroki wdrożenia

1. **Supabase:**
   - utwórz projekt (region Frankfurt);
   - w *SQL Editor* uruchom `supabase/schema.sql`;
   - w *Authentication → Sign In / Providers → Google* wpisz *Client ID* i *Client Secret* z Google Cloud;
   - w *URL Configuration* ustaw Site URL i Redirect URLs (adres strony oraz adres z `/**`).
2. **Google Cloud:**
   - **nie** trzeba włączać Classroom API; jeśli w *Data access* są dodane zakresy Classroom, usuń je — zostają tylko podstawowe (`email`, `profile`, `openid`), które nie wymagają weryfikacji aplikacji przez Google;
   - ustaw *Audience: Internal* (tylko konta z domeny szkoły — najprościej) albo *External* i opublikuj aplikację;
   - utwórz klienta *Web application* z originem strony i redirectem `https://<ID>.supabase.co/auth/v1/callback`.
3. **Konsola administratora szkoły:** *API controls → Manage Third-Party App Access* → aplikacja po Client ID → **Trusted** dla jednostki uczniów. Wymagane dla kont oznaczonych jako niepełnoletnie.
4. **GitHub:** zmień repozytorium na **prywatne**.
5. **Wdrożenie paczki:**
   - usuń ze starego repozytorium plik `index.html` z katalogu głównego;
   - wgraj zawartość paczki (*Add file → Upload files*, przeciągnij foldery);
   - Netlify zbuduje stronę sam.
6. **Pierwsze logowanie:**
   - wejdź na stronę i zaloguj się swoim kontem (zobaczysz „brak dostępu” — to normalne);
   - w *SQL Editor* uruchom `supabase/admin.sql` z wpisanym swoim adresem;
   - kliknij „Sprawdź ponownie”.
7. **Panel nauczyciela** (menu konta → *Panel nauczyciela*) → *Nowa klasa* → *Dodaj uczniów*. Adresy uczniów możesz:
   - **skopiować z Classroom:** zajęcia → *Osoby* → zaznacz wszystkich uczniów → *Działania → Wyślij e-mail* → skopiuj adresy z pola „Do” w Gmailu i wklej (wiadomości nie wysyłaj);
   - **wczytać z konsoli administratora:** *Katalog → Użytkownicy* → filtr jednostki organizacyjnej klasy → *Pobierz użytkowników* (CSV) → w panelu *Wczytaj plik CSV* — imiona i nazwiska dodadzą się same;
   - **wpisać ręcznie:** jeden adres w wierszu, opcjonalnie z imieniem i nazwiskiem.
   Import z Classroom przez API jest wyłączony (wymagałby weryfikacji aplikacji przez Google); można go włączyć w konfiguracji (`"classroom": true`).

## Ograniczenia

- **Darmowy plan Supabase** usypia projekt po ok. 7 dniach bez ruchu (ferie, wakacje). Przywracasz go jednym kliknięciem w panelu Supabase; dane zostają.
- **Awaria Supabase blokuje stronę.** Bez działającego Supabase bramka nie wpuści nikogo — bezpieczniej zamknąć dostęp, niż go otworzyć.
- **Wersja bez logowania** (artifact w claude.ai) działa jak dotąd, z zapisem postępu tylko w przeglądarce.

## Testy wykonane przed wdrożeniem

- **Reguły dostępu (RLS):** 20 przypadków na lokalnym PostgreSQL 16 — podszywanie się, dopisywanie do klas, nadawanie sobie uprawnień, nieaktywni nauczyciele.
- **Scenariusze w przeglądarce:** 20/20, dwukrotnie:
  - logowanie i brak dostępu, bootstrap administratora;
  - klasa ręczna, wklejka adresów z Gmaila i plik CSV z konsoli administratora; import z Classroom (gdy włączony);
  - zapis i odczyt postępu, drugie urządzenie i scalanie, praca offline;
  - wspólny komputer, panel i CSV, odebranie dostępu, zgłoszenie i zatwierdzenie nauczyciela.
- **Środowisko testów:** PostgREST i atrapa logowania Google.

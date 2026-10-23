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

## Nauka indywidualna (od wersji V70)

Nauczyciel przydziela uczniowi materiał (zakres, klasa, cały rok / semestr / wybrane lekcje, tempo albo termin). Uczeń widzi zakładkę **📅 Mój plan** z kartami lekcji do samodzielnej pracy.

**Aktualizacja istniejącego wdrożenia — raz:**
1. **Supabase → SQL Editor:** uruchom `supabase/assignments.sql` (tworzy tabelę `assignments` z regułami dostępu). Plik `schema.sql` też ją zawiera, więc nowe wdrożenia nie potrzebują osobnego kroku.
2. **Uczeń z prywatnym kontem Google (spoza domeny szkoły):** Google Cloud → *Google Auth Platform* → *Audience*: typ **External**, następnie **Publish app** (stan *In production*). Aplikacja używa tylko podstawowych zakresów (`email`, `profile`, `openid`), więc według zasad Google nie wymaga weryfikacji. Dostęp nadal mają tylko adresy dopisane do klas.
3. Ucznia dodajesz jak zwykle: *Panel nauczyciela → Nowa klasa* (np. „Nauczanie indywidualne”) → *Dodaj uczniów* → jego adres Gmail. Potem w kolumnie **Nauka indywidualna** → **📅 Przydziel**.

**Jak działa:** lekcje otwierają się po kolei; zadania z platformy (kurs Python, Ćwiczenia, Zadania bez komputera, sprawdziany z kodem) zaliczają się automatycznie; „Sprawdź się” wymaga co najmniej 70%; prace pisemne i linki uczeń oddaje w karcie lekcji, a nauczyciel zatwierdza je albo odsyła do poprawy z komentarzem. Treści gotowe dla wszystkich klas: zakres podstawowy (klasy 1–3) i rozszerzony (klasy 1–4). W klasach 2–4 kroki z Kursu SQL, Kursu Excel, „Excel na maturze” i arkuszy w trybie egzaminu też zaliczają się automatycznie.

**Tryb planu (od V72):** uczeń z przydziałem widzi uproszczone menu (Start, Mój plan, Do powtórki, Sprawdzian), na stronie startowej kartę bieżącej lekcji z przyciskiem „Kontynuuj”, a w innych zakładkach pasek „← Wróć do planu”. Przyciskiem „☰ Wszystkie moduły” może w każdej chwili wrócić do pełnego menu; wybór zapamiętuje przeglądarka.

## Lekcja na dziś — scenariusze w panelu nauczyciela (od wersji V73; udostępnianie i wyniki klasy od V74)

W każdej klasie przycisk **📘 Lekcja na dziś**. Przy pierwszym otwarciu wybierasz rozkład (zakres podstawowy klasy 1–3 albo rozszerzony klasy 1–4). Potem panel pokazuje kolejną lekcję ze scenariuszy: cele, przebieg z minutami, różnicowanie, sprawdzenie i pracę domową, a obok materiały z przyciskami **Otwórz →**, które przenoszą prosto do właściwego miejsca platformy (z paskiem „← Wróć do scenariusza”).

- **✓ Zrealizowana dziś** zapisuje datę i przechodzi do następnej lekcji; **Cofnij** zdejmuje oznaczenie. Jeśli zaczynasz w trakcie roku, przejdź do bieżącej lekcji i kliknij „Oznacz lekcje 1–… jako zrealizowane”.
- **🔑 Utwórz kod sprawdzianu** — kod z zakresem, liczbą pytań i czasem ze scenariusza.
- **⛶ Na ekran** — temat, cele, kod sprawdzianu i praca domowa dużą czcionką na projektor.
- **📋 Kopiuj temat** — do wpisania w dzienniku; **⬇ Realizacja (CSV)** — wszystkie lekcje z datami realizacji i wymaganiami podstawy programowej.
- **📤 Udostępnij uczniom** — uczniowie klasy zobaczą na stronie startowej kartę „📘 Dziś na lekcji”: kroki lekcji z przyciskami „Otwórz →” (zadania z platformy odhaczają się same) i pracę domową. **Wycofaj** zdejmuje kartę. Wymaga tabeli z pliku `supabase/assignments.sql` (tej samej co nauka indywidualna); plan indywidualny ucznia zostaje nienaruszony.
- **📋 Zadanie do Classroom** (od V75) — wybierasz termin, a aplikacja układa tytuł i instrukcje zadania: temat, zadania z platformy z numerami, pracę domową ze scenariusza, termin i link do aplikacji. Kopiujesz je do Classroom (*Zadania → Utwórz → Projekt*); Classroom powiadamia uczniów i przypomina o terminie, a wykonanie zadań widzisz w „Wynikach klasy”.
- **📊 Wyniki klasy w tej lekcji** — tabela: każdy uczeń × zadania tej lekcji sprawdzane automatycznie (kursy z „Przewidź wynik”, Ćwiczenia, Zadania bez komputera, Excel na maturze, tryb egzaminu) oraz ocena ze sprawdzianu z kodem utworzonym w scenariuszu; w stopce — ilu uczniów zrobiło każde zadanie. Przycisk „⟳ Odśwież wyniki” pobiera najnowsze dane.
- Realizacja zapisuje się na koncie nauczyciela (synchronizacja jak postęp uczniów) — każdy nauczyciel ma własną, osobno dla każdej klasy. Nie wymaga zmian w Supabase.

## Krótkie sesje i tryb telefonu (od wersji V76)

- **⚡ 10 minut** — na stronie startowej karta „Masz 10 minut?”. Jeden przycisk składa sesję: do 4 pytań z powtórek, nowe pytania z bieżącego tematu, jedno „🔮 Przewidź wynik” i jedno zadanie na koniec (z planu ucznia albo kolejne z kursu Python). Pytania po kolei, pasek postępu, podsumowanie.
- **Czas przy krokach** — w planie nauki i w karcie „Dziś na lekcji” każdy krok ma szacowany czas (np. „~6 min”), a lekcja planu — łączny czas.
- **Teoria w pigułce** — każdy z 15 działów Teorii zaczyna się ramką „🧠 3 rzeczy do zapamiętania”; sekcje są zwinięte (pierwsza otwarta), a przykłady odsłaniają się krok po kroku.
- **Tryb telefonu** — na telefonie strona startowa pokazuje kafelki do krótkiej nauki (10 minut, prawda/fałsz, powtórki, słowniczek) i instrukcję dodania aplikacji do ekranu głównego; w kursach i edytorach pojawia się podpowiedź, że to lepiej robić na komputerze. Pliki `manifest.webmanifest`, `icon-192.png` i `icon-512.png` są dostępne bez logowania (bramka je przepuszcza), żeby ikona na ekranie głównym działała. Skrót otwiera aplikację w zwykłej przeglądarce, więc logowanie Google działa tak jak zawsze.
- **Limit powtórek** — „Do powtórki” pokazuje dziennie najwyżej 10 pytań (do zmiany: 5, 10, 20, wszystkie). Po limicie: „Na dziś wystarczy!” z możliwością dobrania kolejnych 10. Plakietka w menu liczy tylko dzisiejszą porcję.

## Prostsze teksty (od wersji V77–V78)

Bez zmian w Supabase i w Netlify — wystarczy wgrać nowe pliki.

- **Krótkie wstępy** — na górze zakładek (Od zera, Ćwiczenia, Do powtórki, Sprawdzian, Teoria, Bez komputera, Excel na maturze, Zbiór CKE, edytory, Słowniczek, arkusze) jest teraz 1–2 zdania; pełny opis jest pod „Więcej ▾”. W arkuszach notka o sprawdzeniu odpowiedzi jest zwinięta („Skąd wiadomo, że odpowiedzi są dobre?”).
- **Mówimy do ucznia** — cele w Kursie Excela i w „Moim planie” są w 2. osobie („W tej lekcji wpisujesz formuły…” zamiast „Po lekcji uczeń wpisuje…”). W panelu nauczyciela cele zostają w formie dla nauczyciela.
- **Formy neutralne** — komunikaty typu „odpowiedziałeś”, „Utknąłeś?”, „Gotowy?” zastąpione formami, które pasują do każdego ucznia.
- **Polecenia na kroki (V78)** — 45 dłuższych poleceń w Kursie Excela (kilka komórek do wypełnienia) ma teraz krótki wstęp i ponumerowane kroki: „1. W kolumnie B… 2. W G7…”. Treść i sprawdzanie się nie zmieniły.
- **„W skrócie” w Teorii (V78)** — każda z 83 sekcji Teorii do matury zaczyna się jednym zdaniem „W skrócie: …”, widocznym także wtedy, gdy sekcja jest zwinięta.
- Wersja angielska dostała odpowiedniki tych zmian.

## Bit — asystent ucznia (od wersji V79)

Bez zmian w Supabase i w Netlify — ustawienie zapisuje się w istniejącej tabeli `assignments`.

- **Domyślnie wyłączony.** Włączasz go dla całej klasy w **Panelu nauczyciela**, w karcie klasy: wiersz „Bit — asystent dla uczniów” → **Włącz** / **Wyłącz**. Uczniowie dodani później: przycisk „Włącz dla wszystkich”.
- **👁 Podgląd u mnie** — włącza Bita tylko w Twojej przeglądarce, żeby zobaczyć, jak wygląda u ucznia.
- **Co robi u ucznia:** karta na stronie Start z jedną propozycją na dziś (powtórki, plan, 10 minut, powrót po przerwie, odliczanie do matury 17.05.2027); krótki dymek po błędnej odpowiedzi (najwyżej raz na kilka błędów, nigdy w Sprawdzianie ani w trybie egzaminu); podpowiedź po drugiej nieudanej próbie w zadaniu kursu; podsumowanie po sesji „10 minut”; jego twarz w podpowiedziach „Pierwszy raz tutaj?”.
- Uczeń może schować kartę do jutra (✕). Zmiana nauczyciela działa po odświeżeniu strony u ucznia (lub po minucie, gdy wraca do karty).
- W wersji bez logowania Bit jest zawsze wyłączony (nie ma tam panelu nauczyciela).

## Mapa opanowania, test na start i „Krok po kroku” (od wersji V80)

Tylko dla ucznia z indywidualnym planem (przydział „📅 Przydziel”). Bez zmian w Supabase — wyniki zapisują się w postępie planu (`mi-ind-v1`), który już się synchronizuje.

- **🧭 Mapa** — nowa zakładka w menu ucznia z planem (także w uproszczonym menu). 15 działów matury (12 w zakresie podstawowym) w kolorach: opanowane / w toku / do poprawy / nie zaczęte. Liczone z odpowiedzi w całej aplikacji: Ćwiczenia, Teoria, Bez komputera, kursy, powtórki.
- **Test na start** — po jednym pytaniu z każdego działu (ok. 15 minut), z przyciskiem „Nie wiem”. Błędy z testu nie trafiają do powtórek. Link do testu jest też w karcie planu na Starcie.
- **🎯 Ćwicz 5 pytań** — z wybranego działu, najpierw pytania z błędem. Mapa sama proponuje najsłabszy dział.
- **🔍 Krok po kroku** — 7 wizualizacji z własnymi danymi i przyciskami ◀ ▶ / Auto: sortowanie (bąbelkowe, przez wstawianie, przez wybieranie), wyszukiwanie binarne, drzewo rekurencji, drzewo BST z przejściami, kopiec, adres IP i maska, zamiana systemów.
- **Nauczyciel** widzi wynik testu i mapę ucznia w panelu, po otwarciu jego planu („📅 …” w wierszu ucznia).

## Prostszy widok ucznia z planem (od wersji V81)

Bez zmian w Supabase. Dotyczy tylko ucznia z indywidualnym planem.

- **Start → „Na dziś”** — jedna karta zamiast pięciu: krótka lista (powtórki → krok planu → test na start, jednorazowo) z czasem przy każdym punkcie, jeden przycisk „▶ Kontynuuj” do pierwszej niezrobionej rzeczy, postęp planu i mały pasek tygodnia. Gdy Bit jest włączony, to on wypowiada tę kartę.
- **Mapa w trzech zakładkach:** Mapa · Test na start · Krok po kroku. Działy w zwijanych grupach (Do poprawy / W toku / Opanowane / Nie zaczęte), szczegóły działu w panelu z boku (na telefonie — arkusz od dołu).
- **Dolny pasek na telefonie:** Dziś · Plan · Mapa · Powtórki (z liczbą na dziś) · Więcej (pełne menu). W Mapie i Powtórkach na telefonie nie ma już paska „Wróć do planu”.

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

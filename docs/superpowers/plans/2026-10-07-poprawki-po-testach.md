# Poprawki po pierwszych testach: czytelność, perki, fauna, zakończenie (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zamienić prototyp "planeta + sklep perków" w grę, którą tester rozumie i chce skończyć: czytelna data, spokojniejszy ekran, podpowiedź "kiedy sadzić", ostrzeżenia o kryzysach, ścieżka życia z postępem, osobne okno perków z gałęziami i poziomami, fauna oraz ekran zakończenia.

**Architecture:** Nowa logika gry (kalendarz, przewodnik po gatunkach, ścieżka życia, zagrożenia, zakończenie) żyje w `game/` jako czyste klasy czytające `PlanetSnapshot` i systemy, a okno (`ui/`) tylko je pokazuje. Perki dalej działają wyłącznie przez modyfikatory współczynników, więc symulacja dostaje kilka nowych współczynników (tolerancje, mnożniki zasiewu, siła kryzysów) z neutralnymi wartościami domyślnymi. Fauna to gatunki w tym samym katalogu z polem `food`: zależą od populacji pokarmu (zlicza się czas jej obfitości), zjadają go i zapylają rośliny. Ostrzeżenie o kryzysie to osobny warunek w danych zdarzenia (`warning`), niezależny od fazy Pending.

**Tech Stack:** Godot 4.7.2 stable, GDScript (typowany), gdUnit4, JSON w `godot/resources/`.

**Spec:** `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md` (rozdziały 2, 3.3, 5.2, 5.4, 8) oraz uwagi testera z 2026-10-07 (tabela poniżej). Ten plan świadomie zmienia założenia specyfikacji: fauna wchodzi przed Etapem 2-4 (Etap 5 specyfikacji), a ostrzeżenia o kryzysach i ekran końca wyprzedzają "Próby Creatora" (Etap 3). Po wykonaniu zaktualizować specyfikację i `docs/plan_rozwoju.md` (Task 16).

## Uwagi testera i gdzie je załatwiam

| # | Uwaga | Zadania |
|---|---|---|
| 1 | "Rok 29, Listopad" zamiast ticków | 1 |
| 2 | za dużo liczb przy gatunkach | 2 |
| 3 | kiedy warunki są optymalne (krzew czy drzewo) | 5 |
| 4 | ostrzeżenie o kryzysie | 6 |
| 5 | osobna karta perków; gałęzie; poziomy | 9, 10, 11, 12 |
| 6 | kronika nad planetą, półprzezroczysta | 3 |
| 7 | zakończenie z gratulacjami | 4 |
| 8 | brak poczucia postępu | 7 |
| 9 | gra mało zachęcająca | 3, 4, 7, 8, 15 |
| 10 | fauna (owady, małe zwierzęta, duże ssaki) | 13, 14 |
| 11 | perki o faunie | 14 |

## Założenia do potwierdzenia (zmiana któregoś = jedno miejsce w danych)

1. **Gra po angielsku (decyzja użytkownika z 2026-10-07).** Cały tekst dla gracza w oknie, danych i konsoli jest po angielsku, także miesiące ("Year 29, November"). Teksty z zadań 1-16 zapisane tu po polsku ("Rok 29, Listopad", "Posadź", "Idealne warunki", "Gratulacje, Praktykancie!", "Iskry") wykonawca tłumaczy: Rok→Year, Iskry→Sparks, Praktykant→Apprentice, Posadź→Plant, Wypuść→Release, Perki→Perks. Dokumenty projektowe zostają po polsku; instrukcja gracza i testera (T16) po angielsku. Zadanie 0 tłumaczy istniejące teksty.
2. **Styl Plague Inc (decyzja użytkownika):** ekran perków jak ekran ewolucji (gałęzie, łańcuchy poziomów, opis po prawej), kronika jak pasek wiadomości nad globusem, ostrzeżenia jak komunikaty o zagrożeniu, bąbelki jak DNA. Gra będzie rozbudowywana (Etapy 2-6), więc dane zostają w JSON, a teksty w jednym miejscu na plik.
3. **Gałęzie perków:** Środowisko (boskie moce, jak dotąd), Odporność (zimno, upał, susza, ogień, wytrzymałość), Rozsiew (więcej sztuk na zasiew, rozsiew naturalny, odbudowa), Produkcja (szybszy wzrost, żyzność, tlen), Tarcza (słabsze i rzadsze kryzysy), Fauna. W uwadze "Zwiększenie produkcji" padło dwa razy; czytam to jako Rozsiew (ilość posadzonych) i Produkcja (tempo i wydajność).
4. **Fauna ma wagę biomasy 0** i nie ma własnego rysunku na globusie (pokazuje ją ścieżka życia, kronika i bąbelki). Powód: suma wag gatunków jest już równa 1,0, a przeliczanie biomasy rozchwiałoby tlen. Wizualizacja fauny na globusie: backlog.
5. **Pierwsze ostrzeżenie każdego rodzaju kryzysu pauzuje grę** i tłumaczy, co robić (kolejne tylko pasek na globusie).
6. **Czas gry 200 lat to miękki koniec:** po roku 200 bez wygranej pokazuje się karta "Czas minął", z możliwością grania dalej. Gniew, Próby i Próba Ostateczna zostają w Etapie 3.
7. **Stare zapisy przestają działać** (inna lista gatunków); okno pokazuje istniejący komunikat `LOAD_FAILED`.

## Fun Detector (werdykty)

| Funkcja | Werdykt | Uzasadnienie i cięcia |
|---|---|---|
| Data zamiast ticków | KEEP | czytelność, zero kosztu |
| Usunięcie liczb "co zrobił gatunek" | KEEP | tester sam o to prosi; strzałki zamiast liczb |
| Przewodnik "kiedy sadzić" | KEEP | tworzy decyzję "teraz czy później"; zielony/żółty/czerwony zamiast tabeli |
| Ostrzeżenia o kryzysach | KEEP | zasada 3: każdy kryzys zapowiedziany i z przeciwdziałaniem |
| Ścieżka życia + postęp | KEEP | odpowiada na "co się dzieje i co dalej" |
| Okno perków, 6 gałęzi, poziomy do III | SIMPLIFY | najwyżej 3 poziomy w linii, 47 perków łącznie; bez drzewa z liniami połączeń, tylko łańcuch chipów |
| Fauna: 3 gatunki | SIMPLIFY | jedno ogniwo pokarmowe na gatunek, bez drapieżników i cykli; wizualizacja POSTPONE |
| Karta końca (wygrana, czas minął) | KEEP | brak końca to dziś najgłośniejsza uwaga |
| Dźwięk, animacje bąbelków | POSTPONE | poza zakresem; tylko napis "+N" przy zebraniu |

## Global Constraints

- Godot 4.7.2 stable; `untyped_declaration` jest błędem: każdy `var`, parametr i zwrot ma typ.
- `simulation/` używa tylko `SimMath` i `SeededRng`, bez sygnałów Godota, bez `PlanetState` (tylko `PlanetSnapshot`); wymusza to `architecture_rules_test.gd`. `game/` i `ui/` mogą używać `RandomNumberGenerator` i sygnałów.
- Nowe współczynniki mają wartości domyślne neutralne (1 albo 0), więc planeta bez perków liczy się tak samo jak dziś, z wyjątkiem dodanej fauny.
- 1 rok = 360 ticków, 1 miesiąc = 30 ticków; partia 200 lat = 72 000 ticków; tempo x5/x10/x25/x50/x100, domyślnie x25 (1500 ticków na minutę, x50 = 3000).
- Perk ma cenę, wymagania i skutek uboczny; najwyżej 3 poziomy w linii; cofnięcie oddaje 70% kosztu.
- Każdy kryzys jest zapowiedziany co najmniej 450 ticków przed startem (18 s przy x25) i ma wymienione przeciwdziałanie.
- Teksty dla gracza po polsku, identyfikatory po angielsku. Liczby w oknie w jednostkach gracza (`DisplayScale`).
- Pliki `.gd` edytować narzędziem Edit (LF, nie CRLF); commitować wygenerowane `*.gd.uid`.
- **Commit i push tylko na prośbę użytkownika.** Krok "Commit" znaczy: przygotuj komunikat (zakończony `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`) i zapytaj.
- Uruchamianie testów (Git Bash), jeden plik:
  `GODOT_BIN="C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" ./godot/run_tests.sh -a res://simulation/tests/<poziom>/<plik>.gd`
  Pełny zestaw bez `-a` (ok. 3 min). Wynik zgłaszać jako linię `N test cases | E errors | F failures` i kod wyjścia (0 = sukces). Dalej zapisuję to jako `RUN <plik>`.
- Złoty ślad (`golden/fixture_trace.txt`) liczy fixture, nie prawdziwe dane: ten plan go nie rusza. Jeśli `golden_trace_test` mimo to padnie, użyć skilla `genesis-determinism-debug`, nie regenerować na ślepo.

## Fazy (każda kończy się grywalnym buildem)

- **Faza A (zadania 1-4):** czytelność i zakończenie. Pytanie do testera: czy rozumiesz, co widzisz, i czy wiesz, kiedy skończyłeś?
- **Faza B (5-8):** prowadzenie gracza: kiedy sadzić, kryzysy, postęp, zachęta. Pytanie: czy wiesz, co zrobić teraz?
- **Faza C (9-12):** perki: gałęzie, poziomy, okno. Pytanie: czy masz na co wydawać Iskry i czy wybory się różnią?
- **Faza D (13-14):** fauna i jej perki. Pytanie: czy zwierzęta są nagrodą?
- **Faza E (15-16):** balans, dokumenty, build.

Kolejność zadań 1-16 jest obowiązująca (zadania 9-12 używają kart i zdarzeń z A i B). Można zatrzymać się po dowolnej fazie.

## Review Focus

Wejścia, których uwagi testera nie opisują, a które najpewniej ugryzą gracza. Każda linia ma test w zadaniu, które posiada kod.

1. **Stary zapis po zmianie listy gatunków** — okno pokazuje `LOAD_FAILED`, nie wywala się (Task 14).
2. **Ostrzeżenie "miga"** — warunek krążący wokół progu daje jedno ostrzeżenie na epizod, nie serię (Task 6).
3. **Fauna bez pokarmu** — pokarm wymarły albo ustawiony na 0 przy żywej faunie: brak NaN, populacje 0..100, pokarm nigdy poniżej 0, przyczyna wymarcia "zabrakło pożywienia" (Task 13).
4. **Karta zakończenia pokazuje się raz** — po "Graj dalej", po zapisie i wczytaniu nie wraca; wygrana i koniec czasu w tym samym ticku: wygrana (Task 4).
5. **Małe okno i kliknięcia** — przy 1024×600 karta i okno perków mieszczą się; przezroczysta kronika i pasek zagrożeń nie zabierają kliknięć bąbelkom na globusie (Task 3, 10, 12).

---

### Task 0: Gra po angielsku (istniejące teksty)

**Files:**
- Modify: wszystkie pliki z tekstem dla gracza: `godot/resources/**/*.json` (chronicle, hints, goals, events, interventions, perks, parameters, personality, display), `godot/game/*.gd`, `godot/ui/*.gd`, `godot/simulation/perks/perk_system.gd`, `godot/export_presets.cfg` (opis produktu, jeśli po polsku)
- Test: istniejące testy z polskimi asercjami (lista: `grep` po znakach diakrytycznych w `godot/simulation/tests`), bez nowych plików

**Interfaces:**
- Consumes: nic.
- Produces: konwencja tekstu dla zadań 1-16: wszystko dla gracza po angielsku. Identyfikatory, klucze JSON i ścieżki bez zmian. Słownik: tick→tick (tylko w logach), rok→year, Iskry→Sparks, Praktykant→Apprentice, Creator→Creator, bąbelek→bubble, perk→perk, kronika→chronicle, gatunki: bacteria, algae, moss, shrub, tree; jednostki (°C, mm/rok→mm/yr, ppm, t/ha, % atmosfery→% of atmosphere).

- [ ] **Step 1: Wyszukaj polskie teksty** — `grep -rn` po znakach `ąćęłńóśźż` w `godot/` poza `addons/` oraz po typowych polskich słowach bez diakrytyków ("jeszcze", "gatunek", "planeta", "Zrobione", "Nie da się"); zapisz liczbę trafień.
- [ ] **Step 2: Przetłumacz** dane i kod; zachowaj sens, długość i znaczniki `{placeholder}`; strukturę zdań "Creator unosi brew: Praktykant…" tłumacz jako "The Creator raises a brow: the Apprentice …". Nazwy parametrów w `parameters.json` i `display.json` ("Średnia temperatura"→"Average temperature").
- [ ] **Step 3: Dostosuj testy** — asercje na tekstach zamieniane na angielskie odpowiedniki; testy liczące słowa polskiej odmiany (np. `ticks_word`) uprościć do angielskiej liczby mnogiej (`tick`/`ticks`).
- [ ] **Step 4: Run** — pełny zestaw bez `-a`. Expected: `0 errors | 0 failures`, kod 0. Ponowne `grep` z kroku 1: brak polskich tekstów poza komentarzami i dokumentami.
- [ ] **Step 5: Commit** — `chore: translate player-facing text to English`

---

### Task 1: Kalendarz gry ("Rok 29, Listopad")

**Files:**
- Create: `godot/game/game_calendar.gd`
- Modify: `godot/resources/display/display.json` (klucz `months`, `display_version` 3), `godot/game/display_scale.gd`, `godot/game/game_session.gd` (`year()`, komunikat odnawiania), `godot/game/goal_tracker.gd` (status celu), `godot/ui/game_view.gd` (pasek, tytuły, linie kroniki)
- Test: `godot/simulation/tests/unit/game_calendar_test.gd`, uzupełnić `integration/game_view_test.gd`, `game_view_live_test.gd`, `goal_tracker_test.gd`

**Interfaces:**
- Consumes: `DisplayScale.load_json(path, parameters, actions)`.
- Produces:
  - `class_name GameCalendar extends RefCounted`: `const TICKS_PER_YEAR := 360`, `const TICKS_PER_MONTH := 30`, `static func year(tick: int) -> int`, `static func month_index(tick: int) -> int` (0-11), `static func date_text(tick: int, months: PackedStringArray) -> String`, `static func duration_text(ticks: int) -> String` ("5 mies.", "2 l. 3 mies."), `static func localize_line(line: String, months: PackedStringArray) -> String` (zamienia prefiks `[Tick N]` na `Rok Y, Miesiąc:`; linie bez prefiksu bez zmian).
  - `DisplayScale.months() -> PackedStringArray` (12 nazw; inna liczba = błąd ładowania).
  - `GameSession.date_text(tick: int = -1) -> String` (-1 = bieżący tick).

- [ ] **Step 1: Write the failing tests**
  - `game_calendar_test.gd`: `test_date_at_tick_zero_is_year_one_january` (`"Rok 1, Styczeń"`), `test_last_tick_of_year_is_december` (359 → `"Rok 1, Grudzień"`), `test_year_rolls_over` (360 → `"Rok 2, Styczeń"`), `test_year_29_november` (10380 → `"Rok 29, Listopad"`), `test_duration_text` (150 → `"5 mies."`, 1170 → `"3 l. 3 mies."`, 0 → `"0 mies."`), `test_localize_line` (`"[Tick 10380] Pojawiają się mchy."` → `"Rok 29, Listopad: Pojawiają się mchy."`; `"UWAGA: x"` bez zmian), `test_display_rejects_wrong_month_count`.
  - `game_view_test.gd`: pasek (`info`) zawiera `"Rok 1"` i nie zawiera `"tick"`; tytuł pauzy `"PAUZA · Rok 1, Styczeń"`; kronika w oknie nie zawiera `"[Tick"`.
  - `goal_tracker_test.gd`: status "jeszcze N ticków" zastąpiony `GameCalendar.duration_text` (np. `"jeszcze 24 mies."`).

- [ ] **Step 2: Run to verify fail** — `RUN unit/game_calendar_test.gd`. Expected: błąd ładowania (brak `GameCalendar`).

- [ ] **Step 3: Implement**
  Dodać `months` do `display.json` i walidacji `DisplayScale`. `GameSession.year()` deleguje do `GameCalendar.year`. `GameView._info`: `"planeta %d · %s   %s"` (seed, `date_text`, stan). `_on_chronicle_line` przepuszcza linię przez `GameCalendar.localize_line` (plik kroniki na dysku zostaje z tickami: to log). `GameSession.submit` zamiast "dostępne od ticku N" mówi "dostępne od: <data>". Konsola (`PlaySession`) zostaje z tickami: to narzędzie.

- [ ] **Step 4: Run tests pass** — `RUN` trzy pliki z "Files"; potem `RUN integration/play_session_test.gd` (konsola bez zmian). Expected: 0 failures.

- [ ] **Step 5: Commit** — `feat: show the game date (Rok N, Miesiąc) instead of ticks in the window`

---

### Task 2: Spokojniejszy ekran: strzałki zamiast liczb

**Files:**
- Modify: `godot/game/game_session.gd`, `godot/ui/game_view.gd`
- Test: `godot/simulation/tests/integration/game_session_test.gd`, `game_view_test.gd`, `game_view_live_test.gd`

**Interfaces:**
- Consumes: `GameSession.planet_rows()`, `life_rows()`, `step()`.
- Produces:
  - `GameSession.TREND_STEP := 90`, `TREND_TICKS := 720`; w trybie `live` `step()` zapisuje próbkę (tick, wartości parametrów, populacje) co `TREND_STEP` ticków, trzymając próbki z ostatnich `TREND_TICKS`.
  - W trybie `live` pole `"change"` wierszy z `planet_rows()` i `life_rows()` to `"▲"`, `"▼"` albo `""` (zmiana względem najstarszej próbki; progi: parametr ≥ pół kroku zaokrąglenia jednostek gracza, populacja ≥ 1,0). Tryb nie-live bez zmian (konsola).
  - W trybie `live` `life_rows()[i]["effects"]` jest `[]`.
  - Usunięte z `GameView`: `life_effects_text`, `others_text`, etykieta `_others`, linie `effects` pod gatunkami. `trend_titles()` zwraca `["Planeta", "Życie"]`.

- [ ] **Step 1: Write the failing tests**
  - `test_live_rows_use_arrows` (po 2000 tickach żadna `change` nie zawiera cyfry, wartości ∈ {"▲","▼",""}); `test_live_trend_follows_recent_window` (biomasa rośnie przy starcie → `"▲"`; po `set_population` spadku → `"▼"` w ciągu `TREND_TICKS`); `test_non_live_rows_keep_numeric_trends` (regresja konsoli); `test_live_life_rows_skip_effects`.
  - `game_view_test.gd`: usunąć asercje `life_effects_text`/`others_text`; `test_window_has_no_effect_lines` (brak etykiety z "Reszta planety" w drzewie węzłów); `test_trend_titles_are_plain`.

- [ ] **Step 2: Run to verify fail** — `RUN integration/game_session_test.gd`.

- [ ] **Step 3: Implement**
  Szerokości komórek tabel: wartość 90, zmiana 24 (`_fill_params`, `_fill_life`). Brak zmian w `SpeciesImpact` (konsola dalej go używa).

- [ ] **Step 4: Run tests pass** — `RUN` trzy pliki; `RUN integration/play_session_test.gd`.

- [ ] **Step 5: Commit** — `feat: arrows instead of per-species effect numbers in the window`

---

### Task 3: Karta na planecie, przezroczysta kronika, układ live

**Files:**
- Create: `godot/ui/overlay_card.gd`, `godot/ui/chronicle_overlay.gd`, `godot/ui/toast.gd`
- Modify: `godot/ui/game_view.gd` (`_build_center`, `_show_intro`, `_show_new_game`, `decision_text`, `chronicle_text`)
- Test: `godot/simulation/tests/integration/overlay_ui_test.gd` (nowy), uzupełnić `game_view_live_test.gd`

**Interfaces:**
- Produces:
  - `class_name OverlayCard extends PanelContainer`: `signal button_pressed(id: String)`; `func show_card(title: String, body_bbcode: String, buttons: Array[Array]) -> void` (`buttons` = `[[id, label], ...]`); `func hide_card() -> void`; `func is_open() -> bool`; `func title_text() -> String`; `func body_text() -> String`; `func content() -> VBoxContainer` (miejsce na dodatkowe kontrolki, np. wybór planety). Wyśrodkowana nad `PlanetView`, tło prawie nieprzezroczyste; otwarta pochłania kliknięcia (`MOUSE_FILTER_STOP`), zamknięta jest niewidoczna.
  - `class_name ChronicleOverlay extends PanelContainer`: `func add_line(bbcode: String) -> void`; `func text() -> String` (pełna kronika); `func visible_lines() -> PackedStringArray` (ostatnie `MAX_LINES := 6`); tło `Color(0.05, 0.08, 0.12, 0.45)`; `mouse_filter = MOUSE_FILTER_IGNORE` na panelu i etykiecie. Przycisk "Kronika" w prawej kolumnie otwiera `AcceptDialog` z pełnym tekstem.
  - `class_name Toast extends Label`: `func show_text(text: String, seconds: float = 4.0) -> void`; `func current_text() -> String`; zanika sam; `MOUSE_FILTER_IGNORE`.
  - `GameView.chronicle_text()` zwraca pełną kronikę; `decision_text()` zwraca tytuł i treść karty, gdy otwarta, inaczej tytuł i treść ukrytego panelu statusu (stare asercje `"Planeta żyje"` zostają prawdziwe). `GameView.card() -> OverlayCard`, `toast() -> Toast`.

- [ ] **Step 1: Write the failing tests** (`overlay_ui_test.gd`)
  - `test_card_shows_title_body_and_buttons` (`button_pressed` niesie id); `test_closed_card_ignores_mouse` (`mouse_filter` IGNORE gdy zamknięta); `test_chronicle_keeps_only_last_lines_visible` (10 linii → `visible_lines().size() == 6`, `text()` zawiera wszystkie); `test_chronicle_overlay_does_not_block_clicks` (`mouse_filter == IGNORE`); `test_toast_expires` (po `seconds` pusty).
  - `game_view_live_test.gd`: `test_live_game_hides_bottom_console` (w trybie live wiersz konsoli niewidoczny); `test_intro_and_new_game_use_the_card` (intro i ekran nowej gry w `card()`, nie w dolnym panelu); `test_window_fits_minimum_size` (przy `GameView.MIN_WINDOW` żaden węzeł karty nie wystaje poza `size`).

- [ ] **Step 2: Run to verify fail** — `RUN integration/overlay_ui_test.gd`.

- [ ] **Step 3: Implement**
  Kronika w `PlanetView` zakotwiczona u góry (margines 12, szerokość 60%, wysokość ~140). W trybie live dolny wiersz konsoli (`console`) jest ukryty, glob zajmuje wolne miejsce; panel decyzji zostaje w drzewie (ukryty) dla trybu nie-live. Intro i ekran nowej gry: kontrolki (numer planety, charakter, "Nowa gra", "Wczytaj ostatnią grę") przeniesione do `card().content()`.

- [ ] **Step 4: Run tests pass** — `RUN` oba pliki, potem `RUN integration/game_view_test.gd` (tryb nie-live nadal działa).

- [ ] **Step 5: Commit** — `feat: overlay card, translucent chronicle and toast above the globe`

---

### Task 4: Zakończenie gry (gratulacje, czas minął)

**Files:**
- Modify: `godot/game/game_session.gd`, `godot/game/goal_tracker.gd`, `godot/game/bubble_field.gd`, `godot/resources/goals/goals.json`, `godot/ui/game_view.gd`
- Test: `godot/simulation/tests/integration/game_ending_test.gd` (nowy), uzupełnić `goal_tracker_test.gd`

**Interfaces:**
- Consumes: `OverlayCard`, `GoalTracker.won()`, `GoalTracker.stars_text()`, `GameCalendar`.
- Produces:
  - `GameSession.GAME_YEARS := 200`; `func outcome() -> String` (`"won"`, `"timeup"` albo `""`; wygrana ma pierwszeństwo); `var ending_seen := false` (zapisywane w `extras`, brak = `false`); `func summary() -> Dictionary` (`"date"`, `"stars"`, `"alive"`, `"total"` = gatunki żyjące/wszystkie, `"perks"`, `"bubbles"`).
  - `BubbleField.collected_count() -> int` (liczone w `collect`, zapisywane w `save_state`, brak = 0).
  - `goals.json` klucz `ending`: `{"won": {"title", "body"}, "timeup": {"title", "body"}}`; `{date}`, `{stars}`, `{alive}`, `{total}`, `{perks}`, `{bubbles}` podstawiane z `summary()`; `GoalTracker.validate` wymaga obu wpisów.
  - `GameView`: gdy `session.live` i `outcome() != "" and not ending_seen`, w `advance()` pauza i karta z przyciskami `[["continue", "Graj dalej"], ["new", "Nowa planeta"]]`; `continue` ustawia `ending_seen = true` i wznawia, `new` otwiera ekran nowej gry. Tekst wygranej zaczyna się od `"Gratulacje, Praktykancie!"`.

- [ ] **Step 1: Write the failing tests**
  - `test_outcome_won_when_goal_reached`; `test_outcome_timeup_after_200_years` (tick ustawiony na `GAME_YEARS * 360`); `test_win_beats_timeup_in_same_tick`; `test_ending_seen_survives_save_and_load` (po zapisie i wczytaniu `outcome()` dalej `"won"`, ale okno nie pokazuje karty); `test_collected_count_counts_each_bubble_once` (podwójny klik = 1).
  - `game_ending_test.gd`: `test_window_shows_congratulations_card_on_victory` (karta otwarta, tytuł/treść zawiera "Gratulacje", gra spauzowana); `test_continue_closes_card_and_resumes_once` (po `continue` kolejne `advance` nie otwiera karty); `test_timeup_card_text`; `test_new_planet_button_opens_new_game_screen`.

- [ ] **Step 2: Run to verify fail** — `RUN integration/game_ending_test.gd`.

- [ ] **Step 3: Implement** — treści w `goals.json` po polsku, ciepłe, bez liczb poza podstawieniami; tekst `timeup` kończy zdaniem o tym, że planetę można dalej rozwijać.

- [ ] **Step 4: Run tests pass** — `RUN` oba pliki + `RUN integration/game_view_live_test.gd`.

- [ ] **Step 5: Commit** — `feat: ending cards for victory and for the end of the 200 years`

---

### Task 5: Przewodnik po gatunkach ("kiedy sadzić")

**Files:**
- Create: `godot/game/species_guide.gd`, `godot/ui/species_panel.gd`
- Modify: `godot/simulation/biosphere/biosphere_system.gd` (`fit_of`), `godot/game/game_session.gd` (`species_guide_rows`), `godot/game/life_zones.gd` (opcjonalna tolerancja, Task 10), `godot/ui/game_view.gd` (panel zamiast listy gatunków przy akcji zasiewu w trybie live)
- Test: `godot/simulation/tests/unit/species_guide_test.gd` (nowy), `integration/game_view_live_test.gd`

**Interfaces:**
- Consumes: `SpeciesData.suitability(snapshot)`, `SpeciesData.limiting_factor(snapshot)`, `BiosphereSystem.population()`, `DisplayScale.shown(id, value)`, nazwy z `ChronicleTexts.species`.
- Produces:
  - `BiosphereSystem.fit_of(species_id: StringName, snapshot: PlanetSnapshot) -> float` (0..1; dziś = `suitability`, po Task 10 i 13 uwzględnia tolerancje i pokarm; `compute` używa tej samej metody: jedno źródło prawdy).
  - `class_name SpeciesGuide extends RefCounted`: `const IDEAL := 0.8`, `const OK := 0.4`; `static func guide(species: SpeciesData, snapshot: PlanetSnapshot, biosphere: BiosphereSystem, scale: DisplayScale, names: Dictionary) -> Dictionary` z kluczami `"id"`, `"name"`, `"verdict"` (`&"ideal"` fit ≥ 0,8; `&"ok"` ≥ 0,4; `&"weak"` > 0; `&"blocked"` = 0; `&"waiting"` gdy poprzednik jeszcze nie żyje), `"label"` ("Idealne warunki", "Dobre warunki", "Słabe warunki", "Za wcześnie: <czego brakuje>", "Czeka na: <poprzednik>"), `"fit"`, `"needs"` (lista `{"name", "range", "now", "state"}` ze stanem `good|poor|bad`; temperatura, woda, CO₂, tlen, gleba), `"why"` (zdanie o najsłabszym czynniku).
  - `GameSession.species_guide_rows() -> Array[Dictionary]` (kolejność katalogu, plus `"cooldown_ready"` z akcji `seed_species` i `"verb"`: "Posadź" dla roślin, "Wypuść" dla fauny).
  - `class_name SpeciesPanel extends VBoxContainer`: `signal plant_requested(species_id: String)`; `func refresh(rows: Array[Dictionary]) -> void`; `func row_text(species_id: String) -> String`; `func plant_button(species_id: String) -> Button`. Wiersz: kolorowa kropka (`ZONE_COLORS`), nazwa, etykieta werdyktu, przycisk; podpowiedź wiersza wypisuje `needs` ("Krzewy lubią: temperatura od 15 °C (masz 12 °C, za zimno) …").
  - `GameView.plant(species_id: String) -> SimResult` wysyła `act("seed_species")` z odpowiednim gatunkiem; w trybie live lista wyboru gatunku przy akcji zasiewu jest ukryta.

- [ ] **Step 1: Write the failing tests** (`species_guide_test.gd`, planeta z `biosphere_fixtures`)
  - `test_ideal_when_every_need_is_met` (temperatura i woda w środku zakresu mchów → `&"ideal"`, etykieta "Idealne warunki"); `test_blocked_names_the_missing_need` (zimno → `&"blocked"`, `"why"` zawiera "zimno" i temperaturę w °C); `test_waiting_for_precursor` (krzewy, mchy = 0 → `&"waiting"`, etykieta "Czeka na: mchy"); `test_needs_report_good_poor_bad` (temperatura w marginesie → `"poor"`); `test_guide_is_read_only` (hash stanu przed i po bez zmian).
  - `game_view_live_test.gd`: `test_species_panel_lists_every_species_with_verdict`; `test_plant_button_submits_seed_with_species` (kliknięcie "Posadź" przy mchach kolejkuje `seed_species` dla `moss`); `test_plant_button_disabled_while_seed_cools_down`.

- [ ] **Step 2: Run to verify fail** — `RUN unit/species_guide_test.gd`.

- [ ] **Step 3: Implement** — progi `IDEAL`/`OK` to stałe z komentarzem, że to próg czytelności (nie symulacji). Zasięgi liczb brać z pól `SpeciesData` (`t_min`, `t_max`, `water_min`, `co2_need`, `o2_need`, `biomass_need`) przez `DisplayScale`.

- [ ] **Step 4: Run tests pass** — `RUN` oba pliki; `RUN integration/biosphere_behavior_test.gd` (refaktor `compute` na `fit_of` nie zmienia wyników).

- [ ] **Step 5: Commit** — `feat: planting guide with per-species verdicts`

---

### Task 6: Ostrzeżenia o kryzysach

**Files:**
- Create: `godot/game/threat_log.gd`, `godot/ui/threat_strip.gd`
- Modify: `godot/simulation/events/event_def.gd`, `event_catalog.gd`, `event_lifecycle.gd`, `event_system.gd`, `godot/resources/events/events.json`, `godot/resources/chronicle/chronicle.json` (zdania ostrzeżeń), `godot/game/game_session.gd`, `godot/ui/game_view.gd`
- Test: `godot/simulation/tests/unit/event_warning_test.gd` (nowy), `integration/event_behavior_test.gd`, `simulation/event_balance_test.gd`, `integration/game_view_live_test.gd`

**Interfaces:**
- Consumes: `EventCondition.parse(raw, schema, label, result)`, `EventLifecycle.advance`.
- Produces:
  - `events.json`: opcjonalny klucz zdarzenia `warning`: `{"condition": {...}, "for_ticks": 20, "clear_ticks": 100, "text": "...", "counters": ["<id perka albo akcji>", ...]}`.
  - `EventDef.warning: EventCondition` (null = bez ostrzeżenia), `warning_ticks: int`, `warning_clear_ticks: int`, `warning_text: String`, `warning_counters: Array[StringName]`.
  - `EventLifecycle`: pola `warned := false`, `warn_streak := 0`, `calm_streak := 0`; `const WARNED := &"warned"`, `WARNING_CLEARED := &"warning_cleared"`; `func advance_warning(def: EventDef, history: ParamHistory) -> StringName`. Reguły: tylko w fazie `INACTIVE`; `warned` po `warning_ticks` kolejnych ticków spełnionego warunku; ostrzeżenie czyści się po `warning_clear_ticks` ticków niespełnionego warunku albo gdy zdarzenie wystartuje (bez osobnego zdarzenia); `to_dict`/`load_dict` zapisują `warned`, `warn_streak`, `calm_streak` (brak w starym zapisie = 0).
  - `EventSystem`: zdarzenia `world_event_warned` (`id`, `name`, `story`, `counters`) i `world_event_warning_cleared` (`id`, `name`, `story`); `func warned_ids() -> Array[StringName]`; `func info_of(id: StringName) -> Dictionary` (`name`, `warning_text`, `counters`).
  - `class_name ThreatLog extends RunObserver`: `func take_new_warnings() -> Array[Dictionary]` (`id`, `name`, `text`, `counters`, `first_time: bool` = pierwszy raz dla tego `id` w tej grze; zapis w `extras["warned_before"]`).
  - `GameSession.threats() -> Array[Dictionary]`: wiersze `{"id", "name", "state" ("warned"|"pending"|"active"), "text", "counters": [{"id", "name", "kind" ("perk"|"action"), "owned": bool}]}` dla zdarzeń w fazach ostrzeżenia, `PENDING` i `ACTIVE`. Przy tworzeniu sesji każdy `counters` musi być id perka albo interwencji, inaczej błąd ładowania.
  - `class_name ThreatStrip extends VBoxContainer`: `signal counter_pressed(kind: String, id: String)`; `func refresh(rows: Array[Dictionary]) -> void`; `func row_text(event_id: String) -> String`. Ostrzeżenie bursztynowe ("⚠ Epoka lodowa zbliża się: …. Pomogą: Lustra orbitalne, Odporność na zimno I"), trwający kryzys czerwony ("Trwa: …"). Pasek jest przezroczysty dla myszy poza przyciskami.
  - `GameView`: pierwsze ostrzeżenie (`first_time`) pauzuje grę i otwiera kartę "Ostrzeżenie: <kryzys>" (przyciski `[["ok", "Rozumiem"], ["perks", "Otwórz perki"]]`, `perks` używa okna z Task 12 po jego dodaniu; do tego czasu przycisk ukryty).
- Początkowe warunki ostrzeżeń (`events.json`, w skali 0-100), do strojenia w kroku 4:
  - `ice_age`: `all[mean(temperature,200) < 22, change(temperature,200) < -0.4]`; counters `res_cold_1`, `perk_mirrors_warm`, `perk_volcanic`.
  - `overheating`: `all[mean(temperature,200) > 36, change(temperature,200) > 0.2]`; counters `res_heat_1`, `perk_mirrors_cool`.
  - `drought`: `all[temperature > 20, anomaly(humidity,500) < -2.0]`; counters `res_drought_1`, `perk_aquifer`, `perk_cloud_seeding`.
  - `fire_season`: `all[oxygen > 16, mean(humidity,100) < 36, biomass > 14]`; counters `res_fire_1`, `perk_aquifer`, `perk_cull`.
  - `guardian_healing` bez ostrzeżenia. (Id perków powstają w Task 11; do tego czasu test ładowania danych tego zadania używa `perk_*` z istniejącego katalogu, a `res_*` dopisuje Task 11 razem z tym wymaganiem.)

- [ ] **Step 1: Write the failing tests** (`event_warning_test.gd`, fixtures z `event_fixtures.gd`)
  - `test_warning_fires_before_trigger` (historia temperatury opadającej: `warned` przed `STARTED`, odstęp ≥ 450 ticków w scenariuszu fixture); `test_warning_needs_for_ticks`; `test_warning_does_not_flicker` (warunek na zmianę spełniony/niespełniony co 10 ticków → dokładnie 1 `WARNED`, 0 `WARNING_CLEARED`, bo `clear_ticks` = 100); `test_warning_clears_after_calm`; `test_start_clears_warning_silently`; `test_no_warning_in_cooldown`; `test_warning_state_survives_save_load`; `test_old_save_without_warning_keys_loads`; `test_catalog_rejects_bad_warning` (brak `condition`, `for_ticks` < 1, nieznany klucz).
  - `event_balance_test.gd` (prawdziwe dane, seedy 1-20, trzy archetypy): `test_every_crisis_is_warned_at_least_450_ticks_ahead` (≥ 80% wystąpień każdego z czterech kryzysów miało `world_event_warned` ≥ 450 ticków przed `world_event_started`) i `test_false_alarm_rate_is_bounded` (≤ 50% ostrzeżeń kończy się `warning_cleared` bez startu).
  - `game_view_live_test.gd`: `test_first_warning_pauses_with_card`; `test_second_warning_of_same_kind_only_updates_strip`; `test_threat_strip_lists_counters`.

- [ ] **Step 2: Run to verify fail** — `RUN unit/event_warning_test.gd`.

- [ ] **Step 3: Implement** — `EventSystem.detect` po `lifecycle.advance` wywołuje `advance_warning` (dla `INACTIVE`/`PENDING` poprzedzającego startu). Ostrzeżenie jest czystą obserwacją: nie zmienia modyfikatorów ani populacji, więc nie dotyka determinizmu tras gry.

- [ ] **Step 4: Tune and run** — `RUN simulation/event_balance_test.gd`; jeśli odstęp albo fałszywe alarmy poza granicami, zmieniać tylko progi `warning` w `events.json` i zapisać wartości końcowe w `docs/events.md`. Potem `RUN integration/event_behavior_test.gd`, `RUN integration/save_system_test.gd`.

- [ ] **Step 5: Commit** — `feat: early warnings for crises with named counters`

---

### Task 7: Ścieżka życia i postęp

**Files:**
- Create: `godot/game/life_path.gd`, `godot/ui/life_path_bar.gd`
- Modify: `godot/game/game_session.gd` (`life_path()`, `next_perk_goal()`), `godot/ui/game_view.gd` (pasek ścieżki nad globusem, napis w pasku Iskier, toasty), `godot/resources/chronicle/chronicle.json`
- Test: `godot/simulation/tests/unit/life_path_test.gd` (nowy), `integration/game_view_live_test.gd`

**Interfaces:**
- Consumes: `SpeciesGuide.guide(...)`, `BiosphereSystem.fit_of`, `BiosphereSystem.population`, `is_lost`, `established_population()`.
- Produces:
  - `class_name LifePath extends RefCounted`: `static func steps(biosphere: BiosphereSystem, snapshot: PlanetSnapshot, scale: DisplayScale, names: Dictionary) -> Array[Dictionary]`; krok = `{"id", "name", "state" ("alive"|"next"|"later"|"lost"), "population", "progress" (0..1), "blocker": String}`. Kolejność: łańcuch `emerges_from` (przodkowie przed potomkami, w kolejności katalogu). `"next"` = pierwszy niezamieszkały krok, którego poprzednik żyje; `progress` = `fit_of` (dla fauny razem z postępem pokarmu po Task 13); `blocker` = `guide["why"]` ("brakuje opadów: 120 mm, trzeba 300 mm") albo `""` gdy nic nie brakuje.
  - `GameSession.life_path() -> Array[Dictionary]` oraz `GameSession.next_perk_goal() -> Dictionary` (`{"name", "cost", "missing"}` dla najtańszego dostępnego niekupionego perka; pusty słownik, gdy nie ma).
  - `class_name LifePathBar extends VBoxContainer`: `func refresh(steps: Array[Dictionary]) -> void`; `func chip_state(species_id: String) -> String`; `func next_text() -> String` ("Następny: Krzewy · brakuje opadów: 120 mm, trzeba 300 mm"). Chipy w jednym rzędzie; "next" ma pasek postępu.
  - `GameView`: na `species_emerged` toast "Pojawiły się <gatunek>! Dalej: <następny krok>" (przez `ThreatLog`-podobną obserwację zdarzeń sesji lub istniejące linie kroniki: wybrać mniej inwazyjne), pasek Iskier pokazuje "Iskry: 7 · najtańszy perk: <nazwa> (brakuje 2)".

- [ ] **Step 1: Write the failing tests**
  - `life_path_test.gd`: `test_steps_follow_succession_order` (bakterie→glony→mchy→krzewy→drzewa); `test_only_one_step_is_next` (przy żywych mchach `next` to krzewy, drzewa `later`); `test_lost_species_marked_lost`; `test_progress_is_fit_of_next_step`; `test_blocker_empty_when_ready`.
  - `game_view_live_test.gd`: `test_path_bar_shows_next_step_and_blocker`; `test_toast_on_new_species` (po pojawieniu się bakterii toast zawiera "bakterie"); `test_sparks_label_shows_next_perk_goal`.

- [ ] **Step 2: Run to verify fail** — `RUN unit/life_path_test.gd`.

- [ ] **Step 3: Implement** — pasek ścieżki w kolumnie środkowej nad `PlanetView`; po Task 14 pokazuje 8 kroków (po Task 13 bez zmian w kodzie, bo kroki wynikają z katalogu).

- [ ] **Step 4: Run tests pass** — `RUN` oba pliki.

- [ ] **Step 5: Commit** — `feat: life path with next step, blocker and progress`

---

### Task 8: Zachęta: pierwsze minuty i informacja zwrotna

**Files:**
- Modify: `godot/ui/bubble_layer.gd`, `godot/simulation/perks/perk_catalog.gd`, `godot/simulation/perks/perk_system.gd`, `godot/resources/perks/perks.json`, `godot/ui/game_view.gd`, `godot/resources/chronicle/hints.json` (tekst wstępu)
- Test: `godot/simulation/tests/unit/perk_system_test.gd`, `integration/bubble_layer_test.gd`, `game_view_live_test.gd`

**Interfaces:**
- Produces:
  - `perks.json`: `"start_sparks": 3` (liczba całkowita ≥ 0); `PerkCatalog.start_sparks: int`; `PerkSystem` startuje z tym saldem (nowa gra); zapis zawiera saldo, więc wczytanie nie dodaje ich drugi raz.
  - `BubbleLayer`: po zebraniu bąbelka etykieta "+N ✦" w miejscu bąbelka unosi się i znika w 1 s (`func floaters() -> PackedStringArray` do testów); `MOUSE_FILTER_IGNORE`.
  - Wstęp (`GameView.LIVE_INTRO`) opisuje pętlę w trzech krótkich krokach: zbieraj Iskry, kup pierwszy perk, patrz na ścieżkę życia; bez wzmianki o tickach.

- [ ] **Step 1: Write the failing tests**
  - `test_new_game_starts_with_start_sparks` (3); `test_loaded_game_does_not_regrant_start_sparks`; `test_catalog_rejects_negative_start_sparks`; `test_collecting_bubble_spawns_floater_with_value` (`"+4"`); `test_floater_removed_after_a_second`; `test_first_perk_affordable_within_first_bubble` (seed 42: pierwszy perk za ≤ 4 Iskry kupiony do ticku 600).

- [ ] **Step 2: Run to verify fail** — `RUN unit/perk_system_test.gd`.

- [ ] **Step 3: Implement** — `start_sparks` czytane w `PerkCatalog.from_data` (klucz w `TOP_KEYS`); `PerkSystem._init` ustawia `_sparks`.

- [ ] **Step 4: Run tests pass** — `RUN` trzy pliki + `RUN simulation/perk_economy_test.gd` (granice dostosować w Task 15, tu tylko sprawdzić, że wynik jest sensowny).

- [ ] **Step 5: Commit** — `feat: start Sparks, bubble feedback and a clearer first minute`

---

### Task 9: Model perków: gałęzie, poziomy, wymagania gatunkowe

**Files:**
- Modify: `godot/simulation/perks/perk_def.gd`, `perk_catalog.gd`, `perk_system.gd`, `godot/game/game_session.gd` (`perk_rows`, `buy_perk`), `godot/simulation/tests/support/perk_fixtures.gd`
- Test: `godot/simulation/tests/unit/perk_catalog_test.gd`, `perk_system_test.gd`, `integration/perk_behavior_test.gd`

**Interfaces:**
- Produces:
  - `perks.json`: klucz `branches`: `[{"id", "name", "help"}]` w kolejności wyświetlania (id: `environment`, `resistance`, `sowing`, `production`, `shield`, `fauna`); perk dostaje opcjonalne `line` (id rodziny, domyślnie id perka), `tier` (1-3, domyślnie 1), `income_scale` (0,1-1, domyślnie 1), `requires_species` (lista id gatunków).
  - `PerkDef`: pola `line: StringName`, `tier: int`, `income_scale: float`, `requires_species: Array[StringName]`; `tree` zostaje nazwą pola (wartość = id gałęzi).
  - `PerkCatalog`: `func branches() -> Array[Dictionary]`; `func line_of(line: StringName) -> Array[PerkDef]` (rosnąco po `tier`); `func check_species(species_ids: Array[StringName], result: SimResult) -> void` (nieznany gatunek w `requires_species` to błąd); stała `TREES` usunięta, `tree` walidowane względem `branches`. Reguły: `tier` > 1 wymaga `line` z perkiem `tier - 1` i tego perka w `requires`; w linii koszt rośnie ze `tier`; najwyżej 3 poziomy.
  - `PerkSystem.income_scale() -> float` (iloczyn `income_scale` kupionych perków); dochód pasywny mnożony przez nią.
  - `GameSession.perk_rows()` dodatkowo: `"branch"` (= `tree`), `"line"`, `"tier"`, `"locked_species"` (nazwy brakujących gatunków; `[]` gdy ok). `GameSession.buy_perk` odrzuca perk z niespełnionym `requires_species` (gatunek żyje albo kiedyś żył: `population ≥ established_population()` lub `is_lost`), komunikat "Najpierw odkryj: <gatunek>.".

- [ ] **Step 1: Write the failing tests**
  - `test_tier_two_must_require_tier_one_of_same_line`; `test_tier_costs_increase_within_line`; `test_rejects_tier_above_three`; `test_rejects_unknown_branch`; `test_line_of_returns_tiers_in_order`; `test_check_species_rejects_unknown_species`; `test_income_scale_multiplies_passive_income` (perk z `income_scale` 0,9 → dochód z biomasy ×0,9); `test_refund_restores_income_scale`; `test_buy_rejected_without_required_species` (przez `GameSession`); `test_buy_allowed_after_species_was_lost`.
  - `perk_fixtures.gd`: `perk(...)` dostaje domyślne `branches`; istniejące testy dostosowane do nowej listy gałęzi.

- [ ] **Step 2: Run to verify fail** — `RUN unit/perk_catalog_test.gd`.

- [ ] **Step 3: Implement** — dane perków zostają na razie w starym kształcie z dopisanymi `branches` (cały nowy katalog w Task 11), a `tree: life` przemianować tymczasowo na `resistance`/`production` zgodnie z gałęziami, żeby dane się ładowały.

- [ ] **Step 4: Run tests pass** — `RUN` trzy pliki + `RUN integration/game_session_economy_test.gd`.

- [ ] **Step 5: Commit** — `feat: perk branches, tiers, species requirements and income scale`

---

### Task 10: Nowe współczynniki symulacji (tolerancje, zasiew, siła kryzysów)

**Files:**
- Create: `godot/simulation/events/event_config.gd`, `godot/resources/events/event_config.json`
- Modify: `godot/simulation/biosphere/biosphere_config.gd`, `species_data.gd`, `biosphere_system.gd`, `godot/resources/biosphere/biosphere.json`, `godot/simulation/events/event_system.gd`, `godot/game/simulation_runner.gd` (`build_planet`: specyfikacje i odciski), `godot/game/life_zones.gd`, `godot/game/game_session.gd`
- Test: `godot/simulation/tests/unit/biosphere_coefficients_test.gd` (nowy), `event_config_test.gd` (nowy), `integration/perk_behavior_test.gd`

**Interfaces:**
- Produces:
  - `BiosphereConfig` nowe pola (zakres, domyślna): `cold_tolerance` [0,40] 0; `heat_tolerance` [0,40] 0; `drought_tolerance` [0,40] 0 (jednostki skali 0-100); `seed_scale` [0,10] 1; `natural_seed_scale` [0,10] 1; `capacity_scale` [0,3] 1 (nie mniej niż 0,1 w danych); `photosynthesis_scale` [0,3] 1.
  - `SpeciesData.suitability(snapshot: PlanetSnapshot, cold: float = 0.0, heat: float = 0.0, drought: float = 0.0) -> float` i `limiting_factor(...)` z tymi samymi opcjonalnymi parametrami (obniżają `t_min` i `water_min` o `cold`/`drought`, podwyższają `t_max` o `heat`); wywołania bez argumentów liczą dokładnie jak dotąd.
  - `BiosphereSystem`: `fit_of` używa tolerancji z `_k`; `compute` mnoży pojemność przez `capacity_scale`, fotosyntezę przez `photosynthesis_scale`, naturalny zasiew przez `natural_seed_scale`; `apply_command(add_population)` dodaje `amount * seed_scale` (z obcięciem do 0..100); `func tolerance() -> Vector3` (zimno, upał, susza).
  - `class_name EventConfig extends RefCounted`: `const DEFAULT_PATH := "res://resources/events/event_config.json"`, `const SPEC := {"severity": [0.1, 1.0, false], "cooldown_scale": [0.1, 10.0, false]}`, pola `severity`, `cooldown_scale`, `static func load_json(path: String) -> SimResult`, `static func neutral() -> EventConfig`.
  - `EventSystem._init(catalog: EventCatalog, archetype: StringName = &"", config: EventConfig = null)`; `coefficients()` zwraca `config` (null = brak celu `events.*`); `coefficient_spec()` = `EventConfig.SPEC`; `apply_coefficients` podmienia efektywną konfigurację. Przy starcie zdarzenia modyfikator `multiply` o wartości `v` rejestruje się jako `1 + (v - 1) * severity`, `add` jako `v * severity`; po końcu zdarzenia `cooldown_left = ceili(def.cooldown * cooldown_scale)`.
  - `build_planet`: `specs` zawiera `&"events": EventConfig.SPEC`; `EventSystem.new(events.value, archetype, event_config)`; `fingerprints` dostaje `"event_config"`.
  - `LifeZones.zone(param, value, species, tolerance: Vector3 = Vector3.ZERO)` i `relevant`: strefy uwzględniają tolerancje (`GameSession.planet_rows` przekazuje `biosphere.tolerance()`).

- [ ] **Step 1: Write the failing tests**
  - `biosphere_coefficients_test.gd`: `test_defaults_leave_suitability_unchanged` (z `fit` liczonym bez i z argumentami zerowymi: równe bitowo); `test_cold_tolerance_extends_cold_edge` (temperatura tuż poniżej `t_min` daje wyższe `suitability` z `cold` = 3); `test_heat_and_drought_tolerance`; `test_seed_scale_multiplies_added_population` (5 × 1,4 = 7); `test_seed_scale_clamps_to_100`; `test_capacity_scale_raises_equilibrium`; `test_natural_seed_scale_speeds_emergence` (seed 42: bakterie pojawiają się wcześniej przy 2,0); `test_photosynthesis_scale_raises_oxygen`; `test_default_run_is_bit_identical_to_before` (hash trasy 3000 ticków z domyślnymi współczynnikami równy hashowi z `neutral` konfiguracją).
  - `event_config_test.gd`: `test_severity_pulls_multiply_toward_one` (0,6 przy 0,5 → 0,8); `test_severity_scales_add`; `test_severity_applies_at_event_start_only` (zmiana w trakcie nie rusza trwającego); `test_cooldown_scale_doubles_cooldown`; `test_events_without_config_behave_as_before`; `test_config_rejects_out_of_range`.
  - `perk_behavior_test.gd`: `test_perk_can_target_events_severity` (kupiony perk z `events.severity` ×0,5 zmienia efektywną wartość).

- [ ] **Step 2: Run to verify fail** — `RUN unit/biosphere_coefficients_test.gd`.

- [ ] **Step 3: Implement** — `LifeZones._limits` dostaje tolerancję jako przesunięcie granic; `SPEC` w `biosphere_config.gd` i `biosphere.json` rozszerzone równocześnie (loader wymaga wszystkich pól).

- [ ] **Step 4: Run tests pass** — `RUN` trzy pliki; potem `RUN simulation/determinism_test.gd`, `RUN simulation/save_load_continuity_test.gd`, `RUN integration/biosphere_behavior_test.gd`.

- [ ] **Step 5: Commit** — `feat: tolerance, seeding and crisis-severity coefficients for perks`

---

### Task 11: Katalog perków (bez fauny)

**Files:**
- Modify: `godot/resources/perks/perks.json`, `godot/simulation/tests/unit/perk_catalog_test.gd`, `integration/perk_behavior_test.gd`, `game_session_economy_test.gd`, `game_view_live_test.gd` (stare id perków), `godot/simulation/tests/simulation/perk_economy_test.gd`, `godot/resources/events/events.json` (id perków w `counters`)
- Test: te same

**Interfaces:**
- Consumes: wszystkie współczynniki z Task 10, `income_scale` z Task 9.
- Produces: katalog 38 perków w pięciu gałęziach (fauna dochodzi w Task 14, razem 47). Id i skutki (tier kumuluje się mnożeniem albo dodawaniem; "uboczny" = drugi modyfikator albo `income_scale`):

| Gałąź | Linia (poziomy: koszt) | Skutek na poziom | Skutek uboczny na poziom |
|---|---|---|---|
| environment | `perk_mirrors_warm` 8, `perk_mirrors_cool` 8, `perk_cloud_seeding` 10, `perk_aquifer` 10, `perk_volcanic` 14 (wymaga `perk_mirrors_warm`), `perk_cull` 6 | odblokowania jak dotąd | jak dotąd |
| resistance | `res_hardy_1/2`: 4, 9 | stres ×0,8 / ×0,85 | wzrost ×0,95 / ×0,97 |
| resistance | `res_cold_1/2/3`: 5, 9, 15 | `cold_tolerance` +3, +3, +4 | wzrost ×0,98, ×0,98, ×0,97 |
| resistance | `res_heat_1/2/3`: 5, 9, 15 | `heat_tolerance` +3, +3, +4 | stres ×1,03 każdy |
| resistance | `res_drought_1/2/3`: 5, 9, 15 | `drought_tolerance` +2, +2, +3 | `fire_rate` ×1,1 każdy |
| resistance | `res_fire_1/2`: 7, 12 | `fire_rate` ×0,7, ×0,6 | wzrost ×0,98, ×0,97 |
| sowing | `sow_amount_1/2/3`: 5, 9, 15 | `seed_scale` ×1,4 każdy | stres ×1,03, ×1,03, ×1,04 |
| sowing | `sow_wind_1/2`: 6, 11 | `natural_seed_scale` ×1,5 każdy | stres ×1,03 |
| sowing | `sow_regrowth_1/2`: 8, 13 | `recolonization` +0,02, +0,03 | stres ×1,05 |
| production | `prod_growth_1/2/3`: 8, 12, 18 | `growth_scale` ×1,15 każdy | stres ×1,05, ×1,05, ×1,06 |
| production | `prod_soil_1/2`: 7, 12 | `capacity_scale` ×1,1 | `fire_rate` ×1,1 |
| production | `prod_oxygen_1/2`: 8, 14 | `photosynthesis_scale` ×1,2 | `fire_rate` ×1,1, ×1,15 |
| shield | `shield_1/2/3`: 8, 14, 22 | `events.severity` ×0,85 każdy | `income_scale` 0,9 każdy |
| shield | `shield_calm_1/2`: 10, 16 | `events.cooldown_scale` ×1,5 każdy | `income_scale` 0,95 każdy |

  Każdy perk ma `help` (jedno zdanie: co robi), `side_effect` (cena w świecie) i `story`. Perki poziomu 2 i 3 wymagają poprzedniego poziomu tej samej linii. Linie mają `line` = prefiks id (`res_cold`, ...). Usuwane id: `perk_hardy`, `perk_fast_growth`, `perk_fire_resistance`, `perk_regrowth`. `events.json` `counters` używa teraz `res_*`/`perk_*`.

- [ ] **Step 1: Write the failing tests** (`perk_catalog_test.gd`)
  - `test_project_data_is_valid` (38 perków, 5 gałęzi, `refund_ratio` 0,7); `test_every_branch_has_perks`; `test_every_perk_has_help_side_effect_and_story`; `test_every_tier_chain_is_complete` (każdy `*_2` wymaga `*_1`, `*_3` wymaga `*_2`); `test_no_branch_exceeds_three_tiers`; `test_event_counters_name_known_perks_or_actions`.
  - `perk_behavior_test.gd`: `test_cold_resistance_helps_survive_ice_age` (seed z epoką lodową: z `res_cold_1..3` najmniejsza populacja drzew w trakcie epoki ≥ 1,5× tej bez perków; wartość strojona w kroku 4); `test_shield_reduces_crisis_effect` (efektywne `growth_scale` w trakcie epoki lodowej przy `shield_3` bliżej 1,0 niż bez); `test_refund_removes_tolerance` (po cofnięciu `res_cold_1` modyfikator znika).

- [ ] **Step 2: Run to verify fail** — `RUN unit/perk_catalog_test.gd`.

- [ ] **Step 3: Implement** — dane; teksty po polsku; nazwy "Odporność na zimno I/II/III". Nie zmieniać kodu poza testami, które odwołują się do starych id.

- [ ] **Step 4: Tune and run** — wartości liczbowe z tabeli to punkt wyjścia. Jeżeli `test_cold_resistance_helps_survive_ice_age` albo odpowiedniki dla upału i suszy nie przechodzą, korygować tylko wartości tolerancji i zapisać końcowe w `docs/perks.md`. Potem `RUN simulation/perk_economy_test.gd` (granice w Task 15), `RUN integration/perk_behavior_test.gd`.

- [ ] **Step 5: Commit** — `feat: 38-perk catalog in five branches with tiers`

---

### Task 12: Okno perków (osobna karta, pauza, gałęzie, łańcuch poziomów)

**Files:**
- Create: `godot/ui/perk_window.gd`
- Modify: `godot/ui/game_view.gd` (przycisk "Perki", pauza przy otwarciu, skrót P), `godot/ui/threat_strip.gd` / karta ostrzeżenia (przycisk "Otwórz perki")
- Delete: `godot/ui/perk_panel.gd` (+ `.uid`), jego użycie w `game_view.gd`
- Test: `godot/simulation/tests/integration/perk_window_test.gd` (nowy), przepisać `game_view_live_test.gd` (sekcje `PerkPanel`)

**Interfaces:**
- Consumes: `GameSession.perk_rows()` (z Task 9), `PerkCatalog.branches()` przez `GameSession.perk_branches() -> Array[Dictionary]` (nowe: `{"id", "name", "help"}`).
- Produces:
  - `class_name PerkWindow extends PanelContainer`: `signal buy_requested(perk_id: String)`, `refund_requested(perk_id: String)`, `closed`; `func open(rows: Array[Dictionary], branches: Array[Dictionary], sparks: int, focus_id: String = "") -> void`; `func refresh(rows: Array[Dictionary], sparks: int) -> void`; `func close() -> void`; `func is_open() -> bool`; `func select(perk_id: String) -> void`; `func selected_id() -> String`; `func detail_text() -> String` (nazwa, "Co robi", "Cena w świecie", koszt, zwrot, wymagania z zaznaczeniem brakujących, brakujące gatunki); `func chip_state(perk_id: String) -> String` (`"owned"|"available"|"unaffordable"|"locked"`); `func buy_button() -> Button`; `func current_branch() -> String`; `func set_branch(branch_id: String) -> void`. Układ: zakładki gałęzi u góry, pod nimi wiersze linii z chipami poziomów ("Odporność na zimno: I → II → III"), po prawej panel opisu z przyciskiem Kup/Cofnij. Zajmuje ~80% obszaru planety, nic nie wystaje poza okno minimalne.
  - `GameView.open_perks(focus_id: String = "") -> void`, `close_perks() -> void`, `perks_open() -> bool`: otwarcie pauzuje grę i zapamiętuje, czy biegła; zamknięcie wznawia tylko gdy biegła. Bąbelki nie starzeją się, dopóki okno otwarte (gra spauzowana). Przycisk w prawej kolumnie: `"Perki ✦ (N do kupienia)"`, gdzie N to liczba perków `available` i `affordable`; skrót klawisza P. Kupno z okna używa `buy_perk`/`refund_perk` widoku (kolejka poleceń jak dotąd; podczas pauzy komunikat "zacznie działać od następnego ticku" w opisie).

- [ ] **Step 1: Write the failing tests** (`perk_window_test.gd`)
  - `test_open_pauses_and_close_resumes_only_if_it_was_running`; `test_branch_tabs_switch_lines`; `test_tier_chips_show_chain_and_state` (`res_cold_2` bez `res_cold_1` → `"locked"`; po zakupie `1` → `"available"`/`"unaffordable"` zależnie od Iskier); `test_selecting_perk_shows_description_and_side_effect`; `test_buy_button_emits_request_and_disabled_when_unaffordable`; `test_refund_button_for_owned_perk_shows_refund_amount`; `test_species_locked_perk_names_missing_species`; `test_window_fits_minimum_size`; `test_bubbles_do_not_age_while_open`; `test_open_with_focus_selects_perk_and_branch` (z karty ostrzeżenia).
  - `game_view_live_test.gd`: sekcje `PerkPanel` zastąpione testami przycisku "Perki ✦" (licznik, otwarcie, skrót P).

- [ ] **Step 2: Run to verify fail** — `RUN integration/perk_window_test.gd`.

- [ ] **Step 3: Implement** — `PerkWindow` buduje chipy z `rows` pogrupowanych po `branch` i `line`, kolejność po `tier`; perki bez `line` to jednoelementowe linie. Panel opisu czyta tylko z wiersza (bez sięgania do systemów).

- [ ] **Step 4: Run tests pass** — `RUN integration/perk_window_test.gd`, `RUN integration/game_view_live_test.gd`, `RUN integration/bubble_layer_test.gd`.

- [ ] **Step 5: Commit** — `feat: perk window with branches and tier chains`

---

### Task 13: Mechanizm fauny w biosferze

**Files:**
- Modify: `godot/simulation/biosphere/species_data.gd`, `species_catalog.gd`, `biosphere_config.gd`, `biosphere_system.gd`, `godot/resources/biosphere/biosphere.json`, `godot/resources/chronicle/chronicle.json` (przyczyny), `godot/simulation/tests/support/biosphere_fixtures.gd`
- Test: `godot/simulation/tests/unit/fauna_test.gd` (nowy), `integration/biosphere_behavior_test.gd`, `simulation/save_load_continuity_test.gd`

**Interfaces:**
- Produces:
  - `SpeciesData` pola opcjonalne (domyślne: puste/0, więc istniejące dane i fixtures zostają ważne): `food: StringName` (id gatunku-pokarmu; puste = roślina), `food_need` [0,100], `food_ticks` [0,10000] (liczba całkowita), `graze` [0,1], `pollinator` [0,1]; `func is_fauna() -> bool` (`food` niepuste). `SpeciesCatalog` waliduje: `food` wskazuje istniejący inny gatunek, a przy `food` `food_need` > 0.
  - `BiosphereConfig` nowe pola: `fauna_growth_scale` [0,10] 1; `fauna_seed_scale` [0,10] 1; `food_need_scale` [0,2] 1 (nie mniej niż 0,1 w danych); `graze_scale` [0,10] 1; `pollination` [0,2] 0.
  - `BiosphereSystem`: wewnętrzne liczniki `_food_streak` (tick całkowity na gatunek fauny): rośnie o 1 przy `pop[food] ≥ food_need * food_need_scale`, w przeciwnym razie maleje o 1 do minimum 0. Naturalny zasiew fauny jest wyłączony, dopóki licznik < `food_ticks` (populacja już istniejąca żyje dalej). Rządzą nią: `fit_of` mnożone przez `food_fit = smoothstep(0, need, pop[food])`; pojemność przez `clamp(pop[food] / (2 * need), 0, 1)`; wzrost mnożony przez `fauna_growth_scale`; zasiew przez `fauna_seed_scale`. Wypas: dla każdej fauny `i` pokarm `f` traci `graze_i * graze_scale * (p_i / 100) * p_f` na tick (populacje z poprzedniego ticku, więc kolejność gatunków nie ma znaczenia; wynik obcięty do ≥ 0). Zapylanie: wzrost roślin warstw ≥ 2 mnożony przez `1 + pollination * Σ(pollinator_i * p_i / 100)`. `LOSS_CAUSES` dostaje `&"hunger"` (fauna z `food_fit` ≤ najniższy inny czynnik) i `&"grazed"` (strata pokarmu przez wypas). `save_state` dodaje `"food_streaks"` (lista liczb całkowitych); `load_state` przyjmuje jego brak jako zera; `losses_exact` ma nowy rozmiar, więc zapisy sprzed zmiany odrzuca istniejąca walidacja.
  - `func food_progress(species_id: StringName) -> float` (0..1 = `streak / food_ticks`, 1 dla roślin i gdy `food_ticks` = 0), używany przez `LifePath`.
  - `chronicle.json` `causes`: `"hunger": "zabrakło pożywienia"`, `"grazed": "zjadły je zwierzęta"`.

- [ ] **Step 1: Write the failing tests** (`fauna_test.gd`, mały katalog: pokarm `moss`, fauna `bug` z `food_need` 20, `food_ticks` 100)
  - `test_fauna_does_not_emerge_while_food_is_scarce` (przy `moss` = 10 przez 1000 ticków `bug` nie pojawia się); `test_fauna_emerges_after_food_streak` (moss = 40: `bug` pojawia się nie wcześniej niż po `food_ticks` ticków); `test_streak_decays_when_food_drops`; `test_fauna_starves_without_food` (moss ustawione na 0 przy `bug` = 30: populacja maleje, przyczyna wymarcia `hunger`); `test_grazing_lowers_food_population` (ten sam seed z fauną i bez: moss niższy z fauną, nigdy < 0); `test_pollination_raises_shrub_growth` (z `pollination` 0,5 krzewy rosną szybciej przy `bug` = 50, równo przy `bug` = 0); `test_populations_stay_within_bounds` (długa symulacja, każda populacja w 0..100, brak NaN); `test_fauna_run_is_deterministic` (dwa przebiegi z tym samym seedem: ta sama trasa); `test_save_and_load_keep_streaks`; `test_old_state_without_food_streaks_loads_as_zero`; `test_catalog_rejects_unknown_food_and_zero_need`; `test_species_without_fauna_fields_still_loads`.
  - `biosphere_behavior_test.gd`: istniejące asercje następstwa bez zmian (rośliny).

- [ ] **Step 2: Run to verify fail** — `RUN unit/fauna_test.gd`.

- [ ] **Step 3: Implement** — dodać przy refaktorze `suit` w `compute` pomocniczą `food_fit(index)`; wypas liczyć w jednej pętli przed `next` (wzór `_taller_cover`). Zachować kolejność: żaden gatunek nie czyta populacji z bieżącego ticku.

- [ ] **Step 4: Run tests pass** — `RUN unit/fauna_test.gd`, `RUN simulation/determinism_test.gd`, `RUN simulation/save_load_continuity_test.gd`, `RUN integration/biosphere_behavior_test.gd`, `RUN integration/save_system_test.gd`.

- [ ] **Step 5: Commit** — `feat: fauna in the biosphere (food, grazing, pollination)`

---

### Task 14: Gatunki fauny, cele, perki o faunie

**Files:**
- Modify: `godot/resources/biosphere/species.json`, `godot/resources/chronicle/chronicle.json` (nazwy), `godot/resources/goals/goals.json`, `godot/resources/perks/perks.json`, `godot/game/simulation_runner.gd` (`PerkCatalog.check_species`), `godot/simulation/tests/integration/goal_tracker_test.gd` (lista gatunków), `game_view_live_test.gd`, `docs/instrukcja_testera.txt` (tylko lista gatunków, reszta w Task 16)
- Test: `godot/simulation/tests/integration/fauna_planet_test.gd` (nowy), `simulation/life_balance_test.gd`, `integration/goal_tracker_test.gd`, `perk_behavior_test.gd`

**Interfaces:**
- Consumes: mechanizm z Task 13; `PerkCatalog.check_species`, `requires_species` z Task 9.
- Produces:
  - Trzy gatunki dopisane na końcu `species.json` (wartości startowe, do strojenia w kroku 4): wszystkie `layer` 0, `weight` 0, `shade` 0, `o2_max` 0, `o2_refuge` 0, `biomass_need` 0, `co2_need` 0, `oxygen` 0, `co2_uptake` 0, `transpiration` 0.

| id | nazwa (kronika) | pokarm / `food_need` / `food_ticks` | poprzednik | wzrost | pojemność | temperatura (min-max, margines) | woda (źródło, min, margines) | `o2_need` | `graze` | `pollinator` | oddychanie | śmiertelność (podst. / stres) | `seed` | `flammable` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `insects` | owady | `moss` / 20 / 360 | `moss` | 0,03 | 70 | 8-42, 8 | humidity, 25, 8 | 10 | 0,004 | 1 | 0,010 | 0,004 / 0,05 | 0,002 | 0,1 |
| `small_animals` | małe zwierzęta | `shrub` / 20 / 540 | `insects` | 0,02 | 60 | 10-42, 8 | precipitation, 5, 4 | 14 | 0,003 | 0 | 0,020 | 0,003 / 0,04 | 0,001 | 0,2 |
| `large_mammals` | duże ssaki | `tree` / 20 / 720 | `small_animals` | 0,012 | 50 | 5-40, 8 | precipitation, 8, 4 | 18 | 0,002 | 0 | 0,035 | 0,002 / 0,03 | 0,0005 | 0,3 |

  - `goals.json`: `victory.species` rozszerzone o `insects`, `small_animals`, `large_mammals`; tekst "Wszystkie etapy życia, od bakterii po duże ssaki, żyją naraz przez 2 lata."; nowe ambicje `first_animals` ("Pierwsze zwierzęta": `insects` populacja ≥ 10) i `big_game` ("Wielka zwierzyna": `large_mammals` ≥ 10); `fast.max_years` ustawione po pomiarze (krok 4).
  - Perki fauny (9, gałąź `fauna`, wszystkie `requires_species: ["insects"]`): `fauna_swarm_1/2/3` (6, 10, 16): `fauna_growth_scale` ×1,3 każdy, uboczny `graze_scale` ×1,2 każdy; `fauna_pantry_1/2` (7, 12): `food_need_scale` ×0,8 każdy, uboczny stres ×1,03; `fauna_pollen_1/2` (9, 15): `pollination` +0,25 każdy, uboczny `graze_scale` ×1,1; `fauna_migrate_1/2` (8, 14): `fauna_seed_scale` ×2 każdy, uboczny stres ×1,03. Łańcuchy poziomów jak w Task 11.

- [ ] **Step 1: Write the failing tests**
  - `fauna_planet_test.gd` (prawdziwe dane, seedy 13, 42, 7): `test_succession_reaches_all_eight_stages_without_player` (w 40 000 ticków każda planeta bez gracza daje przynajmniej owady; dokumentuje, które seedy dochodzą do ssaków); `test_fauna_never_before_its_food` (pierwsze pojawienie owadów po pierwszym mchu, małych zwierząt po krzewach, ssaków po drzewach); `test_planet_chronicle_names_fauna` (zdanie "Pojawiają się owady."); `test_planet_oxygen_stays_in_life_range_with_fauna` (tlen min/max w granicach z `life_balance_test`).
  - `goal_tracker_test.gd`: `ALL` rozszerzone o trzy gatunki; `test_victory_needs_fauna` (bez ssaków `missing_stages() == ["large_mammals"]`).
  - `perk_behavior_test.gd`: `test_fauna_perks_require_insects_discovered`; `test_pollen_perk_raises_shrub_population` (z `fauna_pollen_2` i owadami krzewy ≥ 1,1× kontroli po 5000 ticków); `test_every_fauna_perk_target_exists`.
  - `game_view_live_test.gd`: `test_old_save_is_refused_with_friendly_message` (zapis z pięcioma gatunkami → `error_text()` zawiera `LOAD_FAILED`, brak wyjątku); `test_path_bar_has_eight_steps`.

- [ ] **Step 2: Run to verify fail** — `RUN integration/fauna_planet_test.gd`.

- [ ] **Step 3: Implement** — dane; `build_planet` po załadowaniu katalogów woła `perks.value.check_species(catalog.ids(), failed)`. Nic w `ui/planet_view.gd` (`LIFE_IDS` zostaje roślinami; fauna bez rysunku to założenie 3).

- [ ] **Step 4: Tune and run** — uruchomić `godot/simulation/tests/tools/planet_report.gd --limits` oraz `goal_report.gd` na seedach 1-20 i trzech archetypach; cele: owady pojawiają się w latach 8-25, małe zwierzęta 20-45, duże ssaki 35-80 (zakresy wstępne; zapisać zmierzone w `docs/biosphere.md`); nie zmieniać roślin ani klimatu. Zmieniać tylko wartości z tabeli fauny. Potem `RUN simulation/life_balance_test.gd`, `RUN simulation/planet_balance_test.gd`, `RUN simulation/stability_test.gd`, `RUN integration/goal_tracker_test.gd`; asercje balansu zmieniać tylko z dowodem z narzędzi.

- [ ] **Step 5: Commit** — `feat: insects, small animals and large mammals with fauna perks and goals`

---

### Task 15: Balans ekonomii i długości partii

**Files:**
- Create: `godot/simulation/tests/tools/game_length_report.gd`
- Modify: `godot/resources/bubbles/bubbles.json`, `godot/resources/perks/perks.json` (koszty), `godot/simulation/tests/simulation/perk_economy_test.gd`, `docs/perks.md`
- Test: `perk_economy_test.gd`

**Interfaces:**
- Consumes: wszystkie poprzednie zadania; wzorzec narzędzia: `goal_bot.gd`.
- Produces: `game_length_report.gd`: argumenty `--seeds 1-10 --personality harmonious|chaotic|guardian|all`; bot w trybie live: zbiera każdy bąbelek, kupuje najtańszy dostępny perk, sadzi gatunek z werdyktem `ideal` zaraz po zakończeniu odnowienia; wypisuje na seed: tick wygranej (albo `-`), liczbę kupionych perków, zdobyte Iskry, pierwszy zakup, tick ostrzeżenia i startu każdego kryzysu.
- Cele pomiarowe (do dopasowania danymi `bubbles.json` i kosztami, nie kodem): pierwszy zakup ≤ tick 600; mediana ticku wygranej 25 000-55 000 (8-18 min przy x50); bot wygrywa ≥ 70% partii; kupione perki do wygranej 15-25; łączne Iskry przy wygranej ≥ 120% kosztu 20 najtańszych perków; wszystkie 47 perków kosztuje ≥ 2,5× Iskier zdobytych do wygranej (żadna ścieżka nie kupuje wszystkiego).

- [ ] **Step 1: Write the failing test** — `perk_economy_test.gd` przepisany na nowe granice: `test_first_purchase_is_early` (≤ 600, seedy 13 i 42), `test_income_buys_about_twenty_perks_by_victory_pace` (15-25 kupionych w 40 000 ticków), `test_shop_is_not_exhausted` (suma kosztów kupionych perków < 55% kosztu katalogu przy doskonałym graczu w 72 000 ticków), `test_bubble_rate_stays_in_target` (2,7-4,0 na 1000 ticków).

- [ ] **Step 2: Run to verify fail** — `RUN simulation/perk_economy_test.gd`.

- [ ] **Step 3: Implement the tool and measure** — `GODOT_BIN=... godot --headless --path godot -s res://simulation/tests/tools/game_length_report.gd -- --seeds 1-10 --personality all`. Zapisać tabelę w `docs/perks.md`.

- [ ] **Step 4: Tune** — jeśli mediana wygranej poza zakresem: zmieniać `food_ticks` w `species.json` (nie rośliny). Jeśli perków za mało/za dużo: `bubbles.json` (`discovery.value`, `bloom.value`, progi) i koszty perków. Jedna zmiana naraz, po każdej ponowny pomiar. Zapisać wartości końcowe i zmierzone liczby w `docs/perks.md`.

- [ ] **Step 5: Run full suite** — `RUN` bez `-a`. Expected: `0 errors | 0 failures`, kod 0. Asercje innych testów zmieniać tylko z dowodem z narzędzi.

- [ ] **Step 6: Commit** — `feat: tune bubbles, perk costs and fauna timing to the target game length`

---

### Task 16: Dokumenty, instrukcja testera i build

**Files:**
- Modify: `docs/perks.md`, `docs/biosphere.md`, `docs/events.md`, `docs/jak_grac.md`, `docs/instrukcja_testera.txt`, `docs/plan_rozwoju.md`, `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md` (dopisek "Zmiany 2026-10-07"), `CLAUDE.md` (etap, liczba gatunków, lista struktury plików), `godot/export_game.sh` (pakowanie bez Pythona: `tar -a -c -f` albo `powershell Compress-Archive`)
- Test: weryfikacja `grep` i uruchomienie `export_game.sh`

**Interfaces:**
- Consumes: wszystko powyżej.
- Produces: dokumentacja zgodna z kodem; paczka `build/GenesisError-<data>-<commit>.zip` z `GenesisError.exe` i instrukcją.

- [ ] **Step 1: Zapisz wzorzec do wyszukania nieaktualnych treści**
  `grep -rniE "5 gatunków|pięć gatunków|10 perków|dwa drzewka|Perki \(Iskry|tick [0-9]+ · rok|PerkPanel" CLAUDE.md docs godot/ui godot/game` i zapisz listę.

- [ ] **Step 2: Zaktualizuj dokumenty**
  `docs/perks.md`: tabele 47 perków, gałęzie, wyniki Task 15. `docs/biosphere.md`: fauna (pokarm, licznik obfitości, wypas, zapylanie, przyczyny `hunger`/`grazed`, waga 0, brak rysunku na globusie). `docs/events.md`: pole `warning`, progi, zmierzone odstępy. `docs/jak_grac.md` i `docs/instrukcja_testera.txt`: data, ścieżka życia, okno perków (P), ostrzeżenia, zakończenie; pytania do testera: czy wiedziałeś, kiedy sadzić krzewy/drzewa? czy zauważyłeś ostrzeżenie przed kryzysem? czy okno perków było czytelne? czy zwierzęta były nagrodą? czy wiedziałeś, że skończyłeś? Spec: dopisek, że fauna i ostrzeżenia weszły przed Etapami 2-4 i dlaczego. `plan_rozwoju.md`: "Stan po poprawkach 2026-10-07", kolejny krok (Etap 2 lub 3 po wynikach testu). `CLAUDE.md`: etap rozwoju, "8 gatunków", `ui/` (PerkWindow, ThreatStrip, LifePathBar, OverlayCard).

- [ ] **Step 3: Napraw pakowanie w `export_game.sh`** — zastąpić `python -m zipfile` poleceniem dostępnym na Windows (`tar -a -c -f "$package.zip" "$package"` w katalogu `build`); sprawdzić, że `.zip` powstaje.

- [ ] **Step 4: Zweryfikuj** — ponownie polecenie z kroku 1 (brak trafień poza historią oznaczoną "zastąpione"); pełny zestaw testów `RUN` bez `-a`, oczekiwane `0 errors | 0 failures`; `GODOT_BIN=... ./godot/export_game.sh`, oczekiwany wydruk ścieżki `.zip`; uruchomić zbudowany `GenesisError.exe`, przejść: nowa gra, pierwszy bąbelek, kupno perka w oknie (P), posadzenie mchów z podpowiedzią, ostrzeżenie (przyspieszyć x100).

- [ ] **Step 5: Commit** — `docs: playtest pass 1 (date, guide, warnings, perks, fauna, ending)`

---

## Self-Review

**1. Spec coverage:** każda z 11 uwag ma zadanie (tabela na górze): 1→T1; 2→T2; 3→T5; 4→T6; 5a→T12, 5b→T9/T11/T14, 5c→T9/T11; 6→T3; 7→T4; 8→T7; 9→T3, T4, T7, T8, T15; 10→T13/T14; 11→T14. Zmiana założeń projektu ("nie bój się zmienić") jest jawna w nagłówku i w T16.

**2. Step scan:** kroki podają ścieżki, sygnatury, nazwy testów i wartości; nie ma ciał funkcji poza algorytmami wypasu, licznika i reguł ostrzeżenia, które opisuję słownie, bo nie wynikają z sygnatur. Wartości do strojenia (progi ostrzeżeń, tabela fauny, tolerancje) mają dane startowe, test z granicami i regułę, co wolno zmieniać.

**3. Type consistency:** `fit_of` (T5) używane przez `LifePath` (T7) i rozszerzane w T10/T13; `perk_rows` (T9) czytane przez `PerkWindow` (T12); `OverlayCard` (T3) używany w T4/T6; `GameCalendar` (T1) w T4; `requires_species` (T9) walidowane przez `check_species` w T14; `EventConfig` (T10) używane przez perki `shield_*` (T11). Zależność T6 od id `res_*` z T11 jest opisana w T6 i T11.

**4. Review Focus:** pięć linii powyżej, każda z testem (stary zapis: T14; miganie ostrzeżenia: T6; fauna bez pokarmu: T13; karta raz: T4; małe okno i kliknięcia: T3, T12).

**5. Proportion:** plan jest dłuższy od zlecenia, bo zlecenie to 11 punktów w 5 podsystemach; kod opisuję sygnaturami i testami, nie implementacją.

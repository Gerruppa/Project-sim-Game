# Plan rozwoju Genesis Error

Jeden plik do powrotu do pracy: stan projektu, kolejne etapy, wszystkie
pomysły (także odłożone i odrzucone), zasady i pułapki oraz gotowy prompt
na początek kolejnej sesji (rozdział 5).

---

## 0. Nowy rdzeń od 2026-10-06

Gra przechodzi z "obserwuj planetę" na pętlę w stylu Plague Inc:
gracz jest Praktykantem Creatora, zbiera bąbelki (Iskry Życia), kupuje
perki, przeciwdziała Próbom i ma 200 lat na stworzenie bujnego życia.
Symulacja zostaje globalna (bez regionów).

- Specyfikacja: `docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md`
- Plan (etapy 0-1): `docs/superpowers/plans/2026-10-06-iskry-i-perki.md`
- Księga postępu wykonania: `.superpowers/sdd/2026-10-06-iskry-i-perki/progress.md`

| Etap | Treść | Pytanie do testera |
|---|---|---|
| 0 | dokumenty (`CLAUDE.md`, `CORE_LOOP.md`, `vision.md`, `DESIGN_PRINCIPLES.md`, ten plik) | - |
| 1 | bąbelki, Iskry, sklep perków w oknie; 10 perków (6 Środowisko, 4 Życie) | czy tester klika bąbelki bez podpowiedzi? |
| 2 | zasięg: kontynenty jako dane, `reach`, drzewko Dyspersji, pokrycie na globusie | czy rozświetlanie mapy daje satysfakcję? |
| 3 | Creator: Gniew, Próby z zapowiedzią, Próba Ostateczna, Wskaźnik Życia, wygrana i porażka | czy Próba jest czytelna i uczciwa? |
| 4 | meta: mutacje, Dziedzictwo, trzy scenariusze, wiara ludzkości, ekran końcowy | czy tester zaczyna drugą partię? |
| 5 | fauna: gatunki-konsumenci (osobna specyfikacja po etapie 4) | - |
| 6 | Steam: GodotSteam, osiągnięcia, chmura zapisów, strona sklepu | - |

Kryteria vertical slice (etapy 1-3): partia 15-25 minut, 4-6 bąbelków
na minutę bez podpowiedzi, bot wygrywa 40-60% partii, co najmniej 3 z 5
testerów zaczyna drugą partię bez zachęty, każda Próba jest zapowiedziana
i ma przeciwdziałanie.

Poniższe rozdziały 1-3 to historia i pomiary sprzed zmiany. Etapy A-E
są zastąpione. Rozdział 4 (zasady i pułapki) nadal obowiązuje.

---

## 1. Stan na 2026-10-05 (commit `6c75ebd`)

- Kroki 1-9 z CLAUDE.md gotowe: PlanetState, scheduler, klimat, atmosfera,
  biosfera (5 gatunków w sukcesji), osobowość (3 archetypy), zdarzenia
  i kronika planety, zapis gry, warstwa rozgrywki.
- Gra w konsoli: `./godot/play.sh` (menu, podpowiedzi, wstęp, wskaźniki
  zmian, cele, gwiazdki, ambicje). Tryb komend:
  `./godot/run_simulation.sh` (`--until decision`, `--act`,
  `--load`/`--save`, `--story`).
- Kryzysy (zdarzenia świata): susza, epoka lodowa, przegrzanie, sezon
  pożarów, leczenie planety (tylko Strażnik). Wymieranie prawie trwałe
  (`recolonization` 0,01 w `biosphere.json`).
- 7 interwencji z cooldownami; lustra i pył mają poziomy siły
  (`weak`/`medium`/`strong`).
- Cele: Dojrzała planeta (wygrana), 3 gwiazdki, 7 ambicji
  (`resources/goals/goals.json`).
- 566 testów gdUnit4, pełny zestaw ok. 3 min.
- Narzędzia pomiarowe w `godot/simulation/tests/tools/`:
  - `planet_report.gd` (`--limits`: zakresy i czas przy granicach skali),
  - `intervention_report.gd` (`--at decision|extinction|event:<id>`,
    `--actions a,b`: cena i zysk akcji),
  - `intervention_trace.gd` (szczyt i czas trwania skutku akcji),
  - `event_impact.gd` (`--event id`: wpływ jednego zdarzenia),
  - `goal_report.gd` (cele bez gracza), `goal_bot.gd` (bot grający
    według podpowiedzi).
- Dokumentacja: `docs/jak_grac.md` (instrukcja gracza),
  `docs/gameplay.md` (projekt i pomiary rozgrywki), `docs/events.md`,
  `docs/biosphere.md`, `docs/simulation.md`, `docs/architecture.md`.

---

## 2. Dawne etapy A-E (zastąpione: nowy rdzeń 2026-10-06)

Sekcja zachowana jako historia i źródło pomiarów. Aktualny plan: rozdział 0.

Każdy etap: najpierw Fun Detector, potem architektura, testy (z dowodem
mutacją), pomiar narzędziami z rozdziału 1, dokumentacja, commit na prośbę.

### Etap A. Sesje gry i wnioski (zastąpione: nowy rdzeń 2026-10-06)

Pierwsze wnioski z partii (2026-10-06), już zrobione (szczegóły
`docs/gameplay.md`, „Czytelność po sesjach gry”): odliczanie cooldownu
w sekundach w oknie, panel „Działające akcje” z czasem widocznego skutku,
zwykłe jednostki z punktami kotwiczącymi (`resources/display/display.json`,
start 10 °C, epoka lodowa poniżej 0 °C), kolory stref życia z danych
gatunków. Do sprawdzenia w kolejnych partiach: czy kolory i jednostki
zmieniają decyzje, czy gracz patrzy na skutek w podanym czasie.

Druga runda uwag z okna (2026-10-06), zrobione: układ okna zbudowany na
1366×800 i skalowany z oknem (stretch `canvas_items`/`expand`, minimum
1024×600); komórki tabel o stałej szerokości, długie napisy ucięte
z podpowiedzią, cele i działające akcje przewijane, więc „Dalej” zawsze
widać (test mierzy układ przez 8 rund); przycisk „Cele ★” z pełną listą
celu, gwiazdek i ambicji (gracz nie szukał ambicji, których nie znał);
tempo x5/x10/x25/x100, domyślnie x10 (x1000 służyło do przewijania gry).
Do sprawdzenia: czy gracze otwierają „Cele” i celują w ambicje.

Trzecia runda (2026-10-06), zrobione: planeta jest głównym widokiem
(globus 3D z obrotem i przybliżeniem; kontynenty z numeru planety, reszta
z globalnego stanu, bez regionów w symulacji); wykresy pod przyciskiem;
akcje w pionie po prawej, decyzja i kronika pod globusem; pod każdym
gatunkiem jego zmierzony wpływ od ostatniej decyzji (`SpeciesImpact`),
plus „Reszta planety” i „Twoje akcje”, sumujące się do zmiany w tabeli
(także w konsoli). Renderer Compatibility. Do sprawdzenia: czy globus
pomaga rozumieć planetę, czy wpływ gatunków prowadzi do „co jeśli
zasieję glony?”, czy kontynenty nie obiecują regionów, których nie ma.

- Zagrać 2-3 partie: `./godot/play.sh`, w tym
  `./godot/play.sh --personality chaotic`.
- Zebrać: czy pojawia się „ciekawe, co jeśli…”, które akcje są używane,
  czy podpowiedzi pomagają, czy tempo punktów decyzji jest dobre, czy cele
  motywują.
- Testy zewnętrzne: paczka z `./godot/export_game.sh`, odpowiedzi na
  pytania z `docs/instrukcja_testera.txt` i kroniki partii testerów.
- Wynik: lista poprawek UX i balansu do etapu B.

### Etap B. Domknięcie luk z pomiarów (zastąpione: nowy rdzeń 2026-10-06)

1. **Akcja przyspieszająca natlenienie** (np. zasiew sinic albo
   utlenianie skorupy). Dziś dobra gra nie przyspiesza natlenienia
   (`goal_bot.gd`), bo tlen pochłania skorupa, więc gwiazdka „Szybko”
   zależy bardziej od planety niż od umiejętności.
2. **Kryzys, w którym pomaga przerzedzanie** (np. „gęstwina”: krzewy
   i drzewa duszą niższe warstwy) albo **akcja na sezon pożarów** (np. pas
   przeciwpożarowy). Dziś w pożarach żadna akcja wyraźnie nie pomaga.
3. **Ochrona przed nadużywaniem zasiewu**: wariant 3 z `docs/gameplay.md`
   (siła zasiewu zależna od przydatności środowiska), potem ewentualnie
   dłuższy cooldown. Tylko jeśli etap A pokaże odruch „zawsze sieję”.
4. **Tempo punktów decyzji**: rozważyć pomijanie `species_emerged`
   na początku gry albo grupowanie kilku faktów w jeden punkt.

### Etap C. Narzędzie „co, jeśli…”: porównanie dwóch przyszłości (zastąpione: nowy rdzeń 2026-10-06)

- W menu opcja „rozgałęź”: ten sam punkt decyzji, dwie akcje, obie kroniki
  obok siebie z wyróżnionymi różnicami. Pole `lineage` w zapisie już na to
  czeka.
- Najkrótsza droga do celu gry: „ciekawe, co się stanie, jeśli…”.

### Etap D. Krok 10: wizualizacja debugowa (zastąpione: nowy rdzeń 2026-10-06; okno zostaje głównym interfejsem)

Pierwsza wersja gotowa: `./godot/play_window.sh` (globus 3D, tabele
z wpływem gatunków, kronika, cele, panel decyzji, akcje w kolumnie, tempo
x5/x10/x25/x100, pauza, wykresy pod przyciskiem). Paczka dla testerów zewnętrznych: `./godot/export_game.sh`
(ZIP z `GenesisError.exe` i instrukcją z pytaniami do testera). Dalej:
dopracowanie po sesjach gry i odpowiedziach testerów, potem wizualizacja
docelowa.

- Okno Godota: wykresy parametrów w czasie, kronika na żywo, panel celów,
  przyciski akcji wysyłające te same polecenia
  (`SimulationManager.submit`).
- Reużyć `PlaySession`, `HintAdvisor`, `GoalTracker`, `DecisionWatcher`
  (logika jest już niezależna od konsoli). Symulacji nie zmieniać.
- Zasada z CLAUDE.md: symulacja → logi → wizualizacja debugowa →
  wizualizacja docelowa.

### Etap E. Pogłębienie świata (zastąpione: nowy rdzeń 2026-10-06; fauna to etap 5, scenariusze to etap 4)

- Kolejne gatunki (np. grzyby, beztlenowce głębinowe). Zasada „5 gatunków,
  20 decyzji”: dodawać tylko wtedy, gdy tworzą nowe decyzje.
- Parametry przyszłe z CLAUDE.md (ciśnienie, toksyczność, promieniowanie,
  poziom oceanu, aktywność geologiczna) przez skill `genesis-add-parameter`.
- Scenariusze-wyzwania (np. zimna planeta, wulkaniczna planeta) jako nowe
  pliki współczynników (`--climate`, `--atmosphere`) z własnymi ambicjami.

---

## 3. Pełna lista pomysłów (backlog)

**Rozgrywka**
- akcja przyspieszająca natlenienie
- kryzys, w którym pomaga przerzedzanie; pas przeciwpożarowy
- ochrona przed nadużywaniem zasiewu, pięć wariantów
  (`docs/gameplay.md`): dłuższy cooldown, koszt dla planety, zasiew
  zależny od warunków, malejące przychody `bazowa / (1 + 0,5 · n)`,
  bank nasion
- porównanie dwóch przyszłości (etap C)
- dziennik odkryć: postęp mierzony wiedzą gracza
- rekordy i najlepsze wyniki dla każdego seeda
- scenariusze-wyzwania
- więcej ambicji
- poziomy siły także dla wulkanów i zasiewu chmur
- tempo i grupowanie punktów decyzji
- oś wykresu w oknie w zwykłych jednostkach (dziś 0-100)
- zmierzyć czas widocznego skutku zasiewu (`intervention_trace.gd`) i dopisać
  go do `display.json`, żeby panel „Działające akcje” śledził też zasiew
- tryb komend (`run_simulation.sh`) w zwykłych jednostkach albo w obu

**Symulacja**
- nowe gatunki
- nowe parametry z CLAUDE.md
- balans skorupy i tempa natlenienia
- kolejne kryzysy, zawsze z warunkiem ze stanu planety i zmierzonym
  skutkiem (np. zakwit beztlenowców, katastrofa tlenowa)
- obieg wody silnie się samoreguluje (wilgotność 17-40); do rozważenia,
  jeśli gra ma mieć więcej decyzji „wodnych”

**Odłożone decyzją użytkownika**
- budynki z Master Planu (faza 7): zostają w planie na później
- regiony i mapa
- multiplayer, walka, crafting (Master Plan: nie dodawać)

**Odrzucone pomiarem** (nie wracać bez nowych danych)
- soft capy dla parametrów: żaden parametr nie spędza czasu przy 100
- `recolonization` 0: planety bez gracza utykają na zawsze
- progi „Szybko” poniżej roku 30 i tlen przed rokiem 10: nieosiągalne
  nawet przy dobrej grze

**Techniczne**
- ~~sprawdzić CI na GitHubie (Linux, Windows, macOS) po ostatnich zmianach~~
  zrobione 2026-10-06: zielone na wszystkich trzech (commit `8c6b46b`).
  Logi CI: `gh run view <id> --log-failed` (GitHub CLI zalogowany). Test
  formatujący dokładną połowę (14,25) padał na Linuxie i macOS, bo
  zaokrąglają ją do parzystej, a Windows w górę: w testach wyświetlania
  unikać wartości na granicy zaokrąglenia
- zaktualizować skill `genesis-qa` (pełny zestaw ok. 3 min, nie 1,5)
- zaktualizować stronę postępu
  (https://claude.ai/artifact/EWh6HSDtebjp1J5JkH8DPz) o grę z menu,
  kryzysy i cele
- ewentualnie przełączyć złoty ślad na prawdziwe systemy

---

## 4. Zasady i pułapki

**Sposób pracy**
- Rozmowa po polsku; kod, identyfikatory i część dokumentacji po angielsku.
- Decyzje przedstawiać jako krótkie pytania przed kodem.
- Podczas wykonywania planu wolno robić lokalne commity po każdym zadaniu;
  push tylko na prośbę.
- Fun Detector przed każdą nową funkcją.
- Mierzyć przed strojeniem: wiele seedów i archetypów, narzędzia
  z `tests/tools`, wyniki zapisywać w dokumentacji.
- TDD i dowód, że nowy test potrafi się wywrócić (mutacja).

**Uruchamianie**
- `GODOT_BIN` (Git Bash):
  `C:/Users/jkapk/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`
- wszystkie testy: `./godot/run_tests.sh`; jeden zestaw:
  `./godot/run_tests.sh -a res://simulation/tests/<poziom>/<plik>.gd`

**Pułapki z dotychczasowej pracy**
- Heredoc w bashu psuje się na polskich cudzysłowach („…”). Edycje lepiej
  robić skryptem `.py` zapisanym w scratchpadzie.
- W skryptach `.py` uruchamianych z basha `\\` w tekście potrafi zgubić
  jeden ukośnik, a `Path.write_text` na Windows zapisuje CRLF. Edycje
  plików `.gd` najpewniej narzędziem Edit; po skrypcie sprawdzić
  `git ls-files --eol` (pliki `.gd` muszą mieć LF).
- Błąd kompilacji skryptu uruchamianego przez `-s` (SceneTree) zawiesza
  Godota zamiast go zakończyć. Zawieszone procesy spowalniają testy, więc
  trzeba je sprawdzać i zamykać.
- W typowanym GDScript nie działa `not in` ani literał tablicy w wyrażeniu
  warunkowym przypisywany do `Array[T]`.
- Tablice typu `Packed*Array` w słowniku są kopiowane przy zapisie, więc
  dopisywanie przez słownik ginie.
- Dzielenie całkowite to ostrzeżenie traktowane jako błąd.
- Narzędzie porównawcze musi różnić się tylko mierzoną rzeczą. Pierwsza
  wersja `event_impact.gd` porównywała wszystkie zdarzenia z żadnymi
  i przypisywała kryzysom skutki susz.

---

## 5. Prompt powrotu do pracy

Wklej na początku nowej sesji:

```text
Kontynuujemy projekt Genesis Error (D:\PythonProject_game, Godot 4.7.2,
GDScript), nowy rdzeń w stylu Plague Inc. Przeczytaj najpierw
docs/superpowers/specs/2026-10-06-nowy-rdzen-gry-design.md (specyfikacja),
docs/superpowers/plans/2026-10-06-iskry-i-perki.md (plan) oraz księgę
postępu .superpowers/sdd/2026-10-06-iskry-i-perki/progress.md (które
zadania są zrobione). Potem docs/plan_rozwoju.md (rozdział 0 i zasady
w rozdziale 4) oraz CLAUDE.md. Sprawdź git log i git status, uruchom pełny
zestaw testów (GODOT_BIN jak w planie, ./godot/run_tests.sh) i potwierdź,
że jest zielony.

Potem powiedz w 3-5 zdaniach, na czym skończyliśmy i które zadanie planu
jest następne, i zaproponuj konkretne pierwsze kroki jako krótkie pytania
do decyzji. Pracujemy po polsku; przed nową funkcją Fun Detector ("czy
gracz chce kliknąć jeszcze raz?"), przed strojeniem pomiar, testy z dowodem
mutacją; lokalne commity po zadaniach są dozwolone, push tylko na moją
prośbę.
```

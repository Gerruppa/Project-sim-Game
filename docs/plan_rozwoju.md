# Plan rozwoju Genesis Error

Jeden plik do powrotu do pracy: stan projektu, kolejne etapy, wszystkie
pomysły (także odłożone i odrzucone), zasady i pułapki oraz gotowy prompt
na początek kolejnej sesji (rozdział 5).

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

## 2. Kolejne etapy (zalecana kolejność)

Każdy etap: najpierw Fun Detector, potem architektura, testy (z dowodem
mutacją), pomiar narzędziami z rozdziału 1, dokumentacja, commit na prośbę.

### Etap A. Sesje gry i wnioski (krótki, pierwszy po przerwie)

- Zagrać 2-3 partie: `./godot/play.sh`, w tym
  `./godot/play.sh --personality chaotic`.
- Zebrać: czy pojawia się „ciekawe, co jeśli…”, które akcje są używane,
  czy podpowiedzi pomagają, czy tempo punktów decyzji jest dobre, czy cele
  motywują.
- Wynik: lista poprawek UX i balansu do etapu B.

### Etap B. Domknięcie luk z pomiarów

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

### Etap C. Narzędzie „co, jeśli…”: porównanie dwóch przyszłości

- W menu opcja „rozgałęź”: ten sam punkt decyzji, dwie akcje, obie kroniki
  obok siebie z wyróżnionymi różnicami. Pole `lineage` w zapisie już na to
  czeka.
- Najkrótsza droga do celu gry: „ciekawe, co się stanie, jeśli…”.

### Etap D. Krok 10: wizualizacja debugowa (rozpoczęta)

Pierwsza wersja gotowa: `./godot/play_window.sh` (rysunek planety, wykres,
tabele, kronika, cele, panel decyzji z przyciskami, tempo x10/x100/x1000,
pauza). Dalej: dopracowanie po sesjach gry, potem wizualizacja docelowa.

- Okno Godota: wykresy parametrów w czasie, kronika na żywo, panel celów,
  przyciski akcji wysyłające te same polecenia
  (`SimulationManager.submit`).
- Reużyć `PlaySession`, `HintAdvisor`, `GoalTracker`, `DecisionWatcher`
  (logika jest już niezależna od konsoli). Symulacji nie zmieniać.
- Zasada z CLAUDE.md: symulacja → logi → wizualizacja debugowa →
  wizualizacja docelowa.

### Etap E. Pogłębienie świata (po etapie D, tylko przez Fun Detector)

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
- sprawdzić CI na GitHubie (Linux, Windows, macOS) po ostatnich zmianach
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
- Commit i push tylko na prośbę.
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
GDScript). Przeczytaj najpierw docs/plan_rozwoju.md (stan, etapy, backlog,
zasady i pułapki), CLAUDE.md oraz docs/gameplay.md. Sprawdź git log i git
status, uruchom pełny zestaw testów (GODOT_BIN jak w planie,
./godot/run_tests.sh) i potwierdź, że jest zielony.

Potem powiedz w 3-5 zdaniach, na czym skończyliśmy i który etap planu jest
następny, i zaproponuj konkretne pierwsze kroki tego etapu jako krótkie
pytania do decyzji. Pracujemy po polsku; przed nową funkcją Fun Detector,
przed strojeniem pomiar, testy z dowodem mutacją, commit i push tylko na
moją prośbę.
```

# Symulacja

Wersja: 1.0

Ten dokument opisuje model czasu, determinizm i logowanie symulacji.
Architektura modułów: `docs/architecture.md`.

---

# Cel

Symulacja musi działać samodzielnie, bez UI, grafiki i gracza,
oraz dawać powtarzalne wyniki.

---

# Dane wejściowe i wyjściowe

Wejście:

- seed
- SimConfig (prędkości, interwały systemów)
- definicje danych (parametry, gatunki, zdarzenia, osobowość)
- komendy z CommandQueue

Wyjście:

- zmiany PlanetState
- strumień zdarzeń
- log tick po ticku

---

# Model czasu

- Jeden stały krok symulacji (tick).
- Symulacja nie używa `delta` silnika ani czasu systemowego.
- Czas rzeczywisty decyduje tylko o tym, ile ticków wykonać w klatce.

## Prędkości

| Prędkość | Znaczenie |
|---|---|
| pauza | 0 ticków na sekundę |
| x1 | 1 tick na sekundę (`base_ticks_per_second` w SimConfig) |
| x10 | 10 ticków na sekundę |
| x100 | 100 ticków na sekundę |

Prędkość zmienia liczbę ticków na sekundę. Nigdy nie zmienia rozmiaru ticka.
Dzięki temu wynik po N tickach jest identyczny przy każdej prędkości.
Potwierdza to test `scheduler_determinism_test.gd`
(x1, x10, x100, pauzy i nierówne klatki dają ten sam hash).

Jedno wywołanie `advance()` zwraca najwyżej `max_catch_up_ticks` ticków.
Nadmiar jest odrzucany i liczony: po długim zawieszeniu symulacja
zwalnia zamiast się zamrozić.

## Interwały systemów

Wolne systemy mogą działać co N ticków. Interwał podaje się przy
rejestracji systemu (`register_system(system, interval)`):
system z interwałem K działa w tickach K, 2K, 3K...
Interwał dotyczy liczby ticków, nie sekund.

Poprzednie wartości 1 s, 10 s, 30 s i 60 s
są teraz tylko przykładowymi interwałami, nie mechanizmem prędkości.

---

# Przebieg ticka

```text
1. Begin       komendy, RNG
2. Modifiers   efektywne współczynniki
3. Compute     systemy czytają snapshot, zwracają delty
4. Apply       StateWriter: suma, clamp, walidacja, zapis
5. Detect      EventSystem sprawdza warunki
6. Dispatch    EventBus opróżnia kolejkę (log, obserwatorzy)
7. End         metryki, opcjonalny snapshot
```

Systemy w ticku N czytają stan z końca ticka N-1.
Każda reakcja ma więc naturalne opóźnienie jednego ticka.

---

# Determinizm

Ten sam seed i te same komendy muszą dawać identyczny log.

## Wersja silnika

Silnik jest przypięty: **Godot 4.7.2 stable**.
Determinizm dotyczy konkretnego buildu silnika.
Aktualizacja silnika oznacza świadome przegenerowanie złotego śladu
w osobnym commicie.

## Poziomy determinizmu

| Poziom | Zakres | Status |
|---|---|---|
| L1 | ten sam build, ta sama maszyna | wymagany, testowany przy każdej zmianie |
| L2 | ten sam build, Windows i Linux na x86-64 | cel, wymagany w CI |
| L3 | inne architektury (macOS ARM) | mierzony w CI, bez gwarancji |

Godot nie gwarantuje identycznych wyników obliczeń zmiennoprzecinkowych
między procesorami i systemami. Dlatego L2 i L3 są mierzone, nie zakładane.

Pomiar (GitHub Actions, commity od `692dcd6` do `46091d8`): złoty ślad zgodny
bit w bit na Windows x86-64, Linux x86-64 i macOS ARM. L2 i L3 są spełnione
przy obecnej polityce matematyki, a hipoteza o braku FMA w GDScript
się potwierdziła. Plan B (liczby stałoprzecinkowe) nie jest potrzebny.

## Polityka deterministycznej matematyki

IEEE 754 wymaga poprawnego zaokrąglania dla `+ - * /` i pierwiastka,
więc te operacje dają identyczne bity na każdej zgodnej platformie.
Funkcje przestępne (`sin`, `exp`, `log`, `pow`) zależą od biblioteki
matematycznej platformy.

Reguły:

- kod w `simulation/` używa tylko `+ - * /`, porównań, `abs`, `min`,
  `max`, `clamp`, `floor`, `sqrt`
- potrzebne funkcje (`lerp`, `smoothstep`, potęga całkowita)
  są w `SimMath`, napisane wyłącznie z tych operacji
- zakazane: `sin`, `cos`, `tan`, `exp`, `log`, `pow`, wbudowane `lerp`
  i `smoothstep`, `ease`, `hash`, globalne `randf()`, `randi()`, `seed()`,
  `randomize()`, `randfn()`, `randf_range()`
- regułę egzekwuje test `tests/architecture/architecture_rules_test.gd`

Do zmierzenia (L3): każda operacja GDScript jest osobną instrukcją
maszyny wirtualnej, więc nie powinna zostać połączona w FMA.
To hipoteza, którą weryfikuje złoty ślad na macOS ARM.

## Losowość

- tylko `SeededRng`: jeden niezależny strumień na system
- seed strumienia: pierwsze 15 znaków hex z SHA-256 tekstu
  `"{seed_globalny}:{id_strumienia}"` (nie `hash()`, którego stabilność
  między wersjami nie jest udokumentowana)
- używany jest tylko całkowity rdzeń PCG32 (`randi()`),
  zamiana na float w `SimMath.u32_to_unit_float` (dzielenie przez 2^32)
- stan strumieni jest częścią zapisu gry

## Kolejność

- wynik nie zależy od kolejności rejestracji systemów
- delty są sumowane w kolejności kanonicznej
  (parametr, źródło, przyczyna, wartość), bo dodawanie
  zmiennoprzecinkowe nie jest łączne
- `StringName` porównujemy jako `String`
- brak zależności od FPS i czasu systemowego

## Zapis

- wartości zapisywane są dwukrotnie: dziesiętnie (`values`, dla ludzi)
  i dokładnie (`values_exact`, Base64 bajtów IEEE 754, źródło prawdy)
- liczby całkowite powyżej 2^53 (np. stan RNG) zapisujemy jako tekst,
  bo JSON zamienia liczby na double
- hash stanu: SHA-256 z bajtów, nie z tekstu dziesiętnego
- przy starcie sprawdzana jest kolejność bajtów (little-endian)

Pomiar w Godot 4.7.2: `JSON.stringify(full_precision = true)` odtwarza
wartości dziesiętne bit w bit (także 5e-324). `values_exact` zostaje
jako zabezpieczenie, bo dokumentacja tego nie gwarantuje.

## Złoty ślad

- scenariusz: seed 42, 10 000 ticków, hash stanu co 100 ticków
- plik: `godot/simulation/tests/golden/fixture_trace.txt`
- test porównuje bieżący przebieg z plikiem i podaje pierwszy
  rozbieżny punkt kontrolny
- regeneracja (tylko po świadomej zmianie):
  `godot --headless --path godot -s res://simulation/tests/tools/write_golden_trace.gd`
- plan B, jeśli L2 zawiedzie: wewnętrzna reprezentacja
  w liczbach stałoprzecinkowych; API `PlanetState` po identyfikatorach
  pozwala na to bez zmian w systemach

---

# Logowanie

Każdy tick jest obserwowalny. Ważne zdarzenia są logowane.

Przykład:

```text
[Tick 100]  temperature +2.0   (cause: climate.greenhouse)
[Tick 500]  Species Moss expanded
[Tick 1200] oxygen reached critical threshold
```

Zasady:

- log ma strukturę (tick, źródło, przyczyna, wartość)
- każda delta niesie przyczynę, więc można odtworzyć łańcuch przyczyn
- poziomy logowania i agregacja przy dużych prędkościach (przyszłość;
  na razie `log.deltas` włącza lub wyłącza szczegóły delt)
- logi nie są tymczasowe
- logi zapisywane są w `logs/simulation_runs/` (poza gitem)

## Formaty

Każdy przebieg tworzy dwa pliki z tych samych zdarzeń:
`<run id>.log` (tekst dla ludzi) i `<run id>.jsonl`
(JSON Lines: jeden obiekt JSON w linii, dla narzędzi i analizy balansu).
Identyfikator przebiegu to `seed<N>_<data>_<godzina>`. Data trafia tylko
do nazwy pliku, nigdy do treści, więc ten sam seed daje identyczne bajty.

Tekst:

```text
# Genesis Error simulation log
# seed: 42 | engine: 4.7.2-stable (official) | schema: v1
[Tick 0] initial temperature=30.000 humidity=15.000 oxygen=2.000 biomass=0.000
[Tick 1] temperature 30.000 -> 30.120 (+0.120) [biosphere:shading -0.010, climate:greenhouse +0.130]
[Tick 2] no changes
[Tick 3] biomass 0.010 -> 0.000 (-0.010) [biosphere:dieback -0.020] SATURATED (requested -0.010)
[Tick 4] REJECTED temperature: amount is not finite (...)
[Tick 5] EVENT drought_started from events {"humidity":12.5}
```

JSON Lines (rekordy `run_start`, `tick`, `rejected`, `event`):

```json
{"engine":"4.7.2-stable (official)","initial":{"biomass":0.0,...},"parameters":[...],"record":"run_start","schema_version":1,"seed":42}
{"changes":[{"deltas":[{"amount":0.13,"cause":"greenhouse","source":"climate"}],"new":30.12,"old":30.0,"parameter":"temperature","requested":30.12,"saturated":false}],"record":"tick","tick":1}
```

Klucze są sortowane, a liczby zapisywane z pełną precyzją.
Każdy tick ma dokładnie jeden rekord `tick`, także gdy nic się nie zmieniło.

## Uruchamianie symulacji

```bash
GODOT_BIN=<Godot 4.7.2 console> ./godot/run_simulation.sh                     # 3600 ticków (1 h przy x1), tryb wsadowy
GODOT_BIN=... ./godot/run_simulation.sh --seed 7 --ticks 10000 --quiet
GODOT_BIN=... ./godot/run_simulation.sh --realtime --speed 10 --seconds 60     # czas rzeczywisty
```

Kod wyjścia: 0 = zakończono, 1 = zatrzymano przez odrzuconą paczkę delt,
2 = błędne opcje lub dane.

## Metryki obserwowalności

Cel projektu to ciekawa symulacja. Mierzymy to w logu na 1000 ticków:

- liczba przejść przez progi
- liczba wymierań
- liczba zmian reżimu klimatu
- liczba rozpoczętych zdarzeń

Martwa trajektoria (brak zmian) i wybuchowa trajektoria
(wartości na granicach zakresu) są uznawane za błąd modelu.

---

# Ograniczenia

- wartości parametrów zawsze w zakresach z ParameterDefs
- brak NaN
- brak zależności od UI, grafiki i audio

---

# Kryteria akceptacji

- ten sam seed daje identyczny log po 10 000 ticków
- x1, x10 i x100 dają identyczny wynik po tej samej liczbie ticków
- pauza i wznowienie nie zmieniają wyniku
- zapis w ticku N, wczytanie i M kolejnych ticków
  daje ten sam stan co ciągły bieg N+M

# Przypadki testowe

- unit: TickScheduler (pauza, wznowienie, prędkości, interwały)
- unit: SeededRng (niezależność strumieni, odtwarzanie stanu)
- integration: pełny tick z trzema systemami, kolejność faz
- simulation: wiele seedów, długie przebiegi, brak NaN i zamarcia

---

# Uruchamianie testów

Framework: gdUnit4 6.2.1 (`godot/addons/gdUnit4`).

```bash
GODOT_BIN=/path/to/Godot_v4.7.2-stable_console ./godot/run_tests.sh
```

- bez argumentów uruchamia `res://simulation/tests`
- kod wyjścia 0 = sukces, 100 = błędy, 101 = ostrzeżenia
  (każdy inny niż 0 to porażka)
- raporty HTML i XML: `godot/reports/`
- CI: `.github/workflows/simulation-tests.yml` (Linux, Windows, macOS ARM)

Do czasu powstania domenowych systemów testy symulacyjne napędza
`TestFixtureDynamics` (tylko w `tests/support`), zarejestrowana w prawdziwym
`SimulationManager` jako `TestFixtureSystem`. To nie jest model
planety, tylko generator sprzężonych delt podlegający tej samej
polityce matematyki. Złoty ślad przechodzi przez pełny `TickPipeline`.

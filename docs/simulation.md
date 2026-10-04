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
| x1 | bazowa liczba ticków na sekundę (SimConfig) |
| x10 | 10 × bazowa |
| x100 | 100 × bazowa |

Prędkość zmienia liczbę ticków na sekundę. Nigdy nie zmienia rozmiaru ticka.
Dzięki temu wynik po N tickach jest identyczny przy każdej prędkości.

## Interwały systemów

Wolne systemy mogą działać co N ticków (parametr w SimConfig).
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
- poziomy logowania i agregacja przy dużych prędkościach
- logi nie są tymczasowe
- logi zapisywane są w `logs/simulation_runs/`

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
`TestFixtureDynamics` (tylko w `tests/support`). To nie jest model
planety, tylko generator sprzężonych delt podlegający tej samej
polityce matematyki.

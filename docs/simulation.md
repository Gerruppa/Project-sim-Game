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

Reguły:

- brak globalnego `randf()`, tylko strumienie SeededRng
- jeden niezależny strumień na system
- stan strumieni jest częścią zapisu gry
- wynik nie zależy od kolejności rejestracji systemów
- brak zależności od FPS i czasu systemowego

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

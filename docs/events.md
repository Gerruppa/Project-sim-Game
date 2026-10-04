# Zdarzenia, modyfikatory i osobowość

Wersja: 1.0

Dotyczy EventSystem, ModifierRegistry i PersonalitySystem.
Architektura: `docs/architecture.md`.

---

# Dwa znaczenia słowa "zdarzenie"

W projekcie istnieją dwa różne pojęcia. Nie wolno ich mieszać.

| Pojęcie | Co to jest | Gdzie |
|---|---|---|
| Notyfikacja EventBus | fakt, który już się wydarzył (np. SpeciesCollapsed) | EventBus |
| Zdarzenie świata | zjawisko z fazami (np. susza) | EventSystem |

Zdarzenie świata publikuje notyfikacje o swoim cyklu życia.
Notyfikacje nigdy nie sterują obliczeniami.

---

# ModifierRegistry

Przechowuje aktywne modyfikatory.

Pola modyfikatora:

- cel (identyfikator współczynnika)
- operacja (add, multiply)
- wartość
- źródło
- czas życia

Zasady:

- kolejność operacji: wartość bazowa → add → multiply → clamp
- kolejność rejestracji nie wpływa na wynik
- wygasłe modyfikatory są usuwane
- efektywne współczynniki są liczone raz na tick

---

# PersonalitySystem

Planeta nie jest naprawdę inteligentna. Gracz ma tak czuć.

Archetypy:

- Harmonious
- Chaotic
- Guardian

Każdy archetyp modyfikuje:

- generowanie zdarzeń (progi wrażliwości)
- wzrost ekosystemów
- stabilność klimatu

Zasada:

Zwraca wyłącznie modyfikatory.
Nigdy nie zapisuje stanu świata.

Archetyp jest wybierany na starcie z seeda.
Dwie rozgrywki mają dawać różne efekty.

---

# Stan wdrożenia (krok 6)

- **ModifierRegistry** jest zaimplementowany (`godot/simulation/modifiers/`):
  walidacja celu względem SPEC systemu, kolejność add → multiply → clamp,
  kanoniczne sortowanie, wygasanie (`expires_at`), wersja zestawu.
- **PersonalitySystem** jest zaimplementowany (`godot/simulation/personality/`,
  dane `godot/resources/personality/personality.json`): stałe modyfikatory
  archetypu od ticka 1, zdarzenie `planet_personality`.

Wartości archetypów i ich wpływ (pomiar `planet_report.gd`, 4 seedy × 30 000 ticków, z życiem):

| Archetyp | Czas w lodzie | Las | Gatunków > 5 | Wymierania |
|---|---|---|---|---|
| bez osobowości | 11–18% | 10–30% | 3,1–3,6 | 7–13 |
| Harmonijna | 1–10% | 62–82% | 4,2–4,3 | 2–9 |
| Chaotyczna | 16–22% | 0–13% | 2,5–3,0 | 9–13 |
| Strażnik | 3–14% | 24–51% | 3,5–4,2 | 3–7 |

Planeta chaotyczna została złagodzona po pierwszym pomiarze, w którym CO₂
dotykało 100 (nasycenie), a na jednym seedzie nie powstały drzewa. Przyczyną
były częstsze i głębsze zlodowacenia (pod lodem CO₂ tylko narasta), więc
zmiękczone zostały ich źródła: dryf ×1,35 → ×1,25, limit dryfu ×1,15 → ×1,1,
sezony ×1,2 → ×1,15, pożary ×1,25 → ×1,15, wulkany ×1,25 → ×1,15.
Po zmianie: drzewa na 4/4 seedach, CO₂ maksymalnie 98, nadal najwięcej
zlodowaceń (9–15) i najmniej lasu. Harmonijna jest bardziej bujna niż
w prototypie (62–82% lasu). Wartości są w danych.

---

# Reakcje planety

Decyzja z kroku 6: osobowość ma tylko stałe modyfikatory, a reakcje
planety powstają razem z EventSystem (krok 7), bo potrzebują tej samej
infrastruktury.

**Reakcja to zwykła definicja zdarzenia z polem `personality`** (lista
archetypów). Nie ma osobnego kodu reakcji. Archetyp trafia do EventSystem
jako identyfikator z runnera, więc EventSystem nie zależy od PersonalitySystem.

| Archetyp | Reakcja | Warunek | Efekt (modyfikatory na czas) | Stan |
|---|---|---|---|---|
| Strażnik | "planeta leczy się" (`guardian_healing`) | biomasa spadła o >30% od szczytu z 500 ticków | growth_scale ×1,25, stress_scale ×0,8 | **wdrożona (v1)** |
| Chaotyczna | "niepokój" | długi spokój (mała zmienność temperatury, miara `range`) | przebudzenie wulkanów, silniejszy dryf | planowana |
| Harmonijna | "powrót do równowagi" | temperatura daleko od średniej długookresowej | szybszy powrót temperatury | planowana |

Zasada pozostaje: reakcje działają wyłącznie przez modyfikatory, nigdy przez
bezpośredni zapis stanu. Mają tworzyć wrażenie inteligencji planety,
a ich przyczyna musi być czytelna w logu.

---

# EventSystem

Zdarzenia mają wynikać z symulacji.

Dobrze: "Susza wystąpiła, bo wilgotność załamała się."

Źle: "5% szansy na suszę."

## Każde zdarzenie musi mieć

- warunki wyzwolenia
- fazę aktywną
- warunki zakończenia
- mierzalne efekty

## Miejsce w ticku

Faza 5 (Detect), po Apply, na **nowym** stanie ticka N:

1. zapis próbki do historii parametrów,
2. krok cyklu życia każdego zdarzenia,
3. start: rejestracja modyfikatorów (źródło `event:<id>`); koniec: ich usunięcie,
4. notyfikacje trafiają do Dispatch tego samego ticka.

Modyfikatory działają od fazy 2 ticka N+1. Odrzucona partia nie
uruchamia Detect (tick się nie wydarzył). Log pokazuje start zdarzenia
w ticku stanu, który go wywołał.

## Cykl życia

```text
Inactive → Pending → Active → Cooldown → Inactive
```

| Faza | Znaczenie |
|---|---|
| Inactive | warunek wyzwolenia jest sprawdzany co tick |
| Pending | warunek trwa, ale jeszcze nie `trigger.for_ticks` ticków z rzędu; przerwa wraca do Inactive |
| Active | modyfikatory zarejestrowane; warunek końca sprawdzany od `min_duration`, musi trwać `end.for_ticks` z rzędu; `max_duration` kończy zdarzenie zawsze |
| Cooldown | `cooldown` ticków bez modyfikatorów i bez sprawdzania wyzwolenia |

Przeciw migotaniu: różne warunki wejścia i wyjścia (histereza),
`for_ticks`, `min_duration`. Przeciw zdarzeniu, które samo się podtrzymuje
(susza obniża odbudowę wilgotności): obowiązkowe `max_duration` i `cooldown`.

Implementacja: `EventLifecycle` (czysta maszyna stanów), `EventSystem`
(modyfikatory i notyfikacje).

## Język warunków

Warunek to drzewo w danych (JSON), nie tekst do parsowania: nie ma języka
wyrażeń do walidowania, a dane nie mogą wywołać kodu.

Liść porównuje miarę historii jednego parametru z progiem:

```json
{"measure": "anomaly", "param": "humidity", "window": 500, "op": "<", "value": -3.5}
```

| Miara | Wartość | Potrzebne próbki |
|---|---|---|
| `value` | bieżąca wartość (bez `window`) | 1 |
| `change` | teraz − wartość `window` ticków temu | window + 1 |
| `mean` | średnia z okna | window |
| `min`, `max` | minimum, maksimum okna | window |
| `range` | max − min okna (zmienność) | window |
| `anomaly` | teraz − średnia okna | window |
| `drop_from_peak` | (max okna − teraz) / max okna, ułamek 0..1 | window |

Operatory: `<`, `<=`, `>`, `>=`. Łączniki: `{"all": [...]}`, `{"any": [...]}`,
`{"not": {...}}`. Okno: 1..10000 ticków.

Historia (`ParamHistory`) trzyma bufory cykliczne tylko dla parametrów
z warunków, każdy o długości najdłuższego okna. Miary są liczone zawsze od
najstarszej do najnowszej próbki, bez sum kroczących (dodawanie floatów nie
jest łączne; suma krocząca zależałaby od długości historii i wczytany zapis
rozjechałby się z ciągłym przebiegiem). Dopóki historia nie wypełni okien
zdarzenia, zdarzenie się nie wyzwala.

Warunki czytają tylko PlanetState. Mutacja i katastrofa biologiczna będą
potrzebować danych o gatunkach; to osobna decyzja projektowa.

## Kluczowa zasada

Zdarzenie nie ma własnej ścieżki zapisu do PlanetState.

Aktywne zdarzenie rejestruje modyfikatory na czas fazy aktywnej.
Stan zmienia się przez zwykłe systemy.

Przykład:

Susza nie ustawia wilgotności.
Susza obniża dostępność wody (`climate.water_availability` ×0,85).
ClimateSystem sam wytwarza spadek.

Dzięki temu zdarzenia pozostają emergentne i nie stają się skryptami.

## Definicja w danych

`godot/resources/events/events.json`. Nowe zdarzenie nie wymaga zmian w kodzie.

```json
{
  "id": "drought",
  "name": "Susza",
  "personality": [],
  "trigger": {"condition": {"all": ["..."]}, "for_ticks": 30},
  "end": {"condition": {"measure": "..."}, "for_ticks": 20},
  "min_duration": 60,
  "max_duration": 400,
  "cooldown": 300,
  "modifiers": [{"target": "climate.water_availability", "operation": "multiply", "value": 0.85}]
}
```

`EventCatalog` waliduje przy ładowaniu i zgłasza wszystkie błędy naraz:
parametry ze schematu, cele modyfikatorów ze SPEC systemów, archetypy
z katalogu osobowości, `max_duration > min_duration`, nieznane klucze.
Modyfikatory dla systemów, których planeta nie uruchamia, są pomijane
(jak w osobowości).

## Susza: dlaczego taki warunek

Pomiar (6 seedów × 15 000 ticków, bez osobowości) obalił pierwszy pomysł
"niska wilgotność + brak opadów":

- gdy nie pada, wilgotność jest **wyższa** od średniej (mediana anomalii +8),
  bo to deszcz usuwa parę z powietrza; brak opadów nie jest tu suszą,
- niska wilgotność bezwzględna (< 20) to głównie epoki lodowe
  (zimne powietrze mieści mało wody), też nie susza.

Susza to więc **wyschnięcie powietrza w cieple**: temperatura > 22
i wilgotność o > 3,5 poniżej własnej średniej z 500 ticków (~p5 anomalii),
przez 30 ticków. Koniec: anomalia > −1 przez 20 ticków.

Wynik: 6–11 susz na 15 000 ticków na seed, trwają 80–400 ticków,
ok. 30% kończy się limitem czasu (widoczne sprzężenie: susza podtrzymuje
własną przyczynę, aż limit albo pogoda ją przerwie).

## Planeta leczy się: pomiar

Spadek biomasy > 30% od szczytu występuje 4–11 razy na przebieg.
Seed 42, Strażnik, 15 000 ticków: 6 reakcji, trwają 112–300 ticków,
część kończy się odbudową (spadek od szczytu < 10%), część limitem.

## Losowość

Dozwolona tylko jako modulacja warunków
(np. mutacje), z własnego strumienia SeededRng.
Czysto losowe wyzwalanie bez przyczyny w stanie jest zabronione.
Zdarzenia v1 nie używają losowości.

## Zapis stanu

`EventSystem.save_state()` zapisuje historię (dokładne bajty floatów)
i fazy cyklu życia. Aktywnych modyfikatorów nie zapisuje: `load_state()`
odtwarza je z faz (jedno źródło prawdy). Podpięcie pod pliki zapisu robi
SaveSystem (krok 8).

---

# Narracja

EventSystem publikuje zdarzenia cyklu życia przez EventBus.
Narracja i UI są obserwatorami i tylko je odbierają.

| Notyfikacja | Dane |
|---|---|
| `world_event_started` | id, name, causes (każdy liść: zmierzona wartość, próg, czy spełniony), modifiers, summary |
| `world_event_ended` | id, name, reason (`conditions` / `max_duration`), duration, causes (warunek końca), summary |

Każde zdarzenie świata musi mieć możliwą do odtworzenia przyczynę
(stan, który spełnił warunek). To podstawa uczenia się gracza.
Log tekstowy drukuje `summary`:

```text
[Tick 3799] EVENT world_event_started from events: Planeta leczy się started: biomass max(500) 15.64 > 5.0; biomass drop_from_peak(500) 0.31 > 0.3
[Tick 4000] EVENT world_event_ended from events: Planeta leczy się ended after 201 ticks (end conditions): biomass drop_from_peak(500) 0.06 < 0.1
```

---

# Kryteria akceptacji

| Kryterium | Dowód |
|---|---|
| zdarzenie wyzwala się tylko po spełnieniu warunków ze stanu | `event_lifecycle_test`, `event_system_test` |
| aktywne zdarzenie zmienia współczynniki, nie stan bezpośrednio | `event_system_test.test_never_returns_deltas`, `event_behavior_test` (stan identyczny do chwili działania modyfikatora) |
| zdarzenie kończy się po spełnieniu warunków zakończenia | `event_lifecycle_test`, `event_balance_test` |
| histereza zapobiega migotaniu | `event_lifecycle_test.test_hysteresis_keeps_the_event_between_thresholds` |
| ten sam seed daje te same zdarzenia w tych samych tickach | brak losowości + `event_system_test.test_save_and_load_continue_identically` |
| dwie osobowości dają różne przebiegi | reakcje tylko dla swojego archetypu (`event_system_test`), `personality_character_test` |

# Przypadki testowe

- unit: kolejność operacji modyfikatorów niezależna od rejestracji (`modifier_registry_test`)
- unit: miary historii, bufor cykliczny, dokładny zapis (`param_history_test`)
- unit: parsowanie i ocena języka warunków (`event_condition_test`)
- unit: walidacja definicji (`event_catalog_test`)
- unit: histereza, for_ticks, min/max_duration, cooldown (`event_lifecycle_test`)
- unit: modyfikatory i notyfikacje, archetypy, zapis i odczyt w każdym ticku (`event_system_test`)
- unit: faza Detect widzi nowy stan, modyfikatory działają od następnego ticka (`pipeline_modifiers_test`)
- integration: spadek wilgotności → susza → modyfikator → niższa wilgotność niż bez zdarzeń → koniec (`event_behavior_test`)
- simulation: 3 seedy × 12 000 ticków, susze i leczenie występują i się kończą (`event_balance_test`)

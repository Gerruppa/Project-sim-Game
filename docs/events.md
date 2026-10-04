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
| Chaotyczna | 14–22% | 0–18% | 2,3–3,0 | 10–16 |
| Strażnik | 3–14% | 24–51% | 3,5–4,2 | 3–7 |

Uwagi z pomiaru: planeta chaotyczna na jednym seedzie dotknęła CO₂ = 100
(nasycenie) i na jednym nie wytworzyła drzew w 30 000 ticków; harmonijna
jest bardziej bujna niż w prototypie. Wartości są w danych.

---

# Reakcje planety (wymaganie na krok 7)

Decyzja z kroku 6: osobowość ma na razie tylko stałe modyfikatory.
**Reakcje planety budujemy razem z EventSystem**, bo potrzebują tej samej
infrastruktury (warunki, faza aktywna, warunki końca, histereza, modyfikatory
z czasem wygaśnięcia). Archetyp ma wpływać na to, które reakcje występują
i z jakimi progami. Przykłady do zaprojektowania:

| Archetyp | Reakcja | Warunek (przykład) | Efekt (modyfikatory na czas) |
|---|---|---|---|
| Strażnik | "planeta leczy się" | biomasa spada o >30% od ostatniego szczytu | szybszy wzrost, mniejszy stres życia |
| Chaotyczna | "niepokój" | długi spokój (mała zmienność temperatury) | przebudzenie wulkanów (więcej CO₂), silniejszy dryf |
| Harmonijna | "powrót do równowagi" | temperatura daleko od normy | szybszy powrót temperatury |

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

## Cykl życia

```text
Inactive → Triggered → Active → Ending → Inactive
```

Wyzwolenie i zakończenie używają histerezy
(inny próg wejścia i wyjścia), żeby zdarzenia nie migotały.

## Kluczowa zasada

Zdarzenie nie ma własnej ścieżki zapisu do PlanetState.

Aktywne zdarzenie rejestruje modyfikatory na czas fazy aktywnej.
Stan zmienia się przez zwykłe systemy.

Przykład:

Susza nie ustawia wilgotności.
Susza obniża współczynnik odbudowy wilgotności.
ClimateSystem sam wytwarza spadek.

Dzięki temu zdarzenia pozostają emergentne i nie stają się skryptami.

## Pierwsze zdarzenia

- Susza
- Burza
- Erupcja
- Mutacja
- Katastrofa biologiczna

Definicje leżą w danych (EventDefs).
Nowe zdarzenie nie wymaga zmian w kodzie.

## Losowość

Dozwolona tylko jako modulacja warunków
(np. mutacje), z własnego strumienia SeededRng.
Czysto losowe wyzwalanie bez przyczyny w stanie jest zabronione.

---

# Narracja

EventSystem publikuje zdarzenia cyklu życia przez EventBus.
Narracja i UI są obserwatorami i tylko je odbierają.

Każde zdarzenie świata musi mieć możliwą do odtworzenia przyczynę
(stan, który spełnił warunek). To podstawa uczenia się gracza.

---

# Kryteria akceptacji

- zdarzenie wyzwala się tylko po spełnieniu warunków ze stanu
- aktywne zdarzenie zmienia współczynniki, nie stan bezpośrednio
- zdarzenie kończy się po spełnieniu warunków zakończenia
- histereza zapobiega migotaniu
- ten sam seed daje te same zdarzenia w tych samych tickach
- dwie osobowości dają różne przebiegi przy tym samym seedzie świata

# Przypadki testowe

- unit: kolejność operacji modyfikatorów niezależna od rejestracji
- unit: histereza wyzwolenia i zakończenia
- unit: wygasanie modyfikatorów
- integration: spadek wilgotności → susza → modyfikatory → dalszy spadek → koniec
- simulation: wiele seedów, zdarzenia nie trwają w nieskończoność

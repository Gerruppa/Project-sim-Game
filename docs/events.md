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

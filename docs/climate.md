# Klimat i atmosfera

Wersja: 1.0

Dotyczy ClimateSystem i AtmosphereSystem.
Architektura: `docs/architecture.md`.

---

# Cel

Planeta ma reagować na własne warunki.
Zmiana jednego parametru ma wywoływać reakcję łańcuchową.

---

# ClimateSystem

## Odpowiedzialność

- temperatura
- wilgotność
- opady
- trendy pogodowe

Jest właścicielem dynamiki temperatury i wilgotności.

## Wejścia

- snapshot PlanetState (temperatura, wilgotność, biomasa, tlen)
- efektywne współczynniki z ModifierRegistry

## Wyjścia

Delty dla temperatury i wilgotności. Każda delta ma przyczynę.

## Zdarzenia

- TemperatureChanged
- HumidityChanged
- ClimateShift (zmiana reżimu klimatu)

## Zależności (kierunki wpływu)

- temperatura → wilgotność
- biomasa → wilgotność (parowanie roślin)
- biomasa → temperatura (albedo, osłona)
- tlen i inne gazy → temperatura (w przyszłości CO₂)

Konkretne wzory i współczynniki leżą w danych, nie w kodzie.
Model ma być prosty. Złożoność wynika z interakcji.

---

# AtmosphereSystem

## Odpowiedzialność

- regulacja tlenu
- stabilność atmosfery
- ciśnienie (przyszłość)

Jest właścicielem dynamiki tlenu.

## Wejścia

- snapshot (tlen, biomasa, temperatura)
- efektywne współczynniki

## Wyjścia

Delty dla tlenu (przyszłość: ciśnienie, CO₂).

## Zdarzenia

- OxygenChanged
- PressureChanged
- AtmosphereCrisis

## Zależności

- biomasa i gatunki → tlen (strumień produkcji z BiosphereSystem)
- tlen → rozwój życia (przez BiosphereSystem)
- temperatura → zanik i rozpuszczanie gazów

Biosfera nie ma własnej kopii tlenu.
Gatunek zwraca strumień produkcji jako deltę z przyczyną.
Regulację i zanik wykonuje AtmosphereSystem.

---

# Reguły wspólne

- systemy nie znają się nawzajem
- czytają stan z końca poprzedniego ticka
- nie zapisują stanu bezpośrednio, tylko zwracają delty
- wartości zawsze w zakresach z ParameterDefs
- wszystkie współczynniki są w danych i podlegają modyfikatorom

---

# Kompromisy projektowe

Dążymy do kompromisów (zasada "brak idealnej strategii"):

- więcej tlenu = większe ryzyko pożarów
- więcej biomasy = mniejsza stabilność ekologiczna
- więcej opadów = większe prawdopodobieństwo mutacji

Te zależności powinny wynikać ze współczynników w danych,
nie z osobnych skryptów.

---

# Kryteria akceptacji

- zmiana temperatury o stałą wartość wywołuje mierzalną zmianę
  wilgotności i biomasy w kolejnych tickach
- bez ingerencji parametry zmieniają się samoczynnie
  i pozostają w zakresach
- 60 minut symulacji bez błędów (kryterium fazy 1)
- ten sam seed daje ten sam wynik

# Przypadki testowe

- unit: każda delta ma źródło i przyczynę
- unit: clamp do zakresów
- integration: łańcuch temperatura → wilgotność → biomasa → tlen
- simulation: wiele seedów, brak NaN, brak trwałego zamarcia

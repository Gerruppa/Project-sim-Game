# Biosfera

Wersja: 1.0

Dotyczy BiosphereSystem i danych gatunków.
Architektura: `docs/architecture.md`.

---

# Cel

Powstanie i ewolucja życia w skali całej planety.

Najważniejszy system rozgrywki.

---

# Filozofia

Nigdy nie symulujemy pojedynczych organizmów.
Symulujemy populacje.

Cel to symulacja ekosystemów na dużą skalę,
nie symulacja stworzeń.

---

# Odpowiedzialność

- populacje gatunków
- wzrost
- śmiertelność i wymieranie
- wpływ na środowisko

Jest właścicielem dynamiki biomasy.

## Wejścia

- snapshot PlanetState
- SpeciesData
- efektywne współczynniki (osobowość, zdarzenia)

## Wyjścia

Delty dla biomasy oraz strumienie do tlenu i wilgotności.
Każda delta ma przyczynę (np. gatunek i rodzaj wpływu).

## Zdarzenia

- SpeciesExpanded
- SpeciesCollapsed
- EcologicalShift

---

# SpeciesData

Każdy gatunek zawiera:

- populację początkową
- tempo wzrostu
- śmiertelność
- wymagania środowiskowe (zakres temperatury, wilgotności, tlenu)
- efekty środowiskowe (produkcja i konsumpcja)

Dane MVP: bakterie, glony, mech, krzew, drzewo.

---

# Reguły projektowania gatunku

Każdy gatunek musi odpowiadać na pytania:

1. Co zużywa?
2. Co produkuje?
3. Jakiego środowiska wymaga?
4. Co się stanie, gdy zniknie?
5. Co się stanie, gdy zdominuje planetę?

Bez odpowiedzi projekt gatunku jest niekompletny.

Dodanie gatunku wymaga tylko nowego zasobu danych, nie zmian w kodzie.

---

# Dynamika populacji

- populacja rośnie, gdy środowisko mieści się w wymaganiach
- populacja maleje, gdy środowisko wychodzi poza wymagania
- populacja spadająca do zera oznacza wymarcie (zdarzenie)
- gatunek nie istnieje w PlanetState, ale jego efekty tak
- wymieranie i dominacja mają skutki systemowe
  (zmiana tlenu, wilgotności, biomasy)

Szybko rosnący gatunek daje szybki start,
ale może stać się inwazyjny (kompromis krótko- i długoterminowy).

---

# Reguły wspólne

- biosfera nie przechowuje kopii parametrów planety
- nie zapisuje stanu bezpośrednio, tylko zwraca delty
- losowość (mutacje) tylko z własnego strumienia SeededRng
- efekty zależą od współczynników z danych

---

# Kryteria akceptacji

- gatunki same rosną lub wymierają w zależności od środowiska
- zmiana środowiska zmienia populacje w kolejnych tickach
- wymarcie gatunku zmienia stan planety w mierzalny sposób
- dodanie gatunku nie wymaga zmian w kodzie

# Przypadki testowe

- unit: wzrost w zakresie wymagań, spadek poza nim
- unit: wymarcie przy populacji zero
- integration: gatunek produkujący tlen podnosi tlen przez AtmosphereSystem
- simulation: wiele seedów, brak NaN, brak wiecznego wzrostu

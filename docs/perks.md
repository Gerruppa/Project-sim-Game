# Iskry, bąbelki i perki (Etap 1)

Pętla Etapu 1: z globusa wyskakują bąbelki, kliknięcie daje Iskry Życia,
za Iskry kupuje się perki w sklepie w oknie gry. Dane: `godot/resources/perks/perks.json`
i `godot/resources/bubbles/bubbles.json`. Kod: `PerkSystem`, `BubbleField`,
`GameSession` (tryb live, w oknie włączony domyślnie).

## Perki (10)

Koszt w Iskrach. Zwrot perka oddaje 70% kosztu (zaokrąglone w dół).
"Wymaga" znaczy, że perk trzeba najpierw kupić.

### Drzewko Życie (modyfikatory biosfery)

| Perk | Koszt | Wymaga | Skutek | Skutek uboczny |
|---|---|---|---|---|
| Wytrzymałość | 4 | - | stres ×0,8 | wzrost ×0,95 |
| Szybki wzrost | 12 | Wytrzymałość | wzrost ×1,2 | stres ×1,1 |
| Odporność na ogień | 10 | Wytrzymałość | pożary ×0,6 | wzrost ×0,97 |
| Odbudowa | 8 | - | rekolonizacja +0,02 | stres ×1,05 |

### Drzewko Środowisko (odblokowują działania)

| Perk | Koszt | Wymaga | Odblokowuje | Skutek uboczny |
|---|---|---|---|---|
| Lustra orbitalne | 8 | - | `mirrors_warm` | zbyt mocne ogrzanie przegrzewa życie |
| Pył orbitalny | 8 | - | `mirrors_cool` | zbyt mocny pył wywołuje epokę lodową |
| Zasiew chmur | 10 | - | `cloud_seeding` | deszcz wysusza powietrze, mchy i glony cierpią |
| Wody podziemne | 10 | - | `aquifer_release` | więcej chmur ochładza planetę |
| Przebudzenie wulkanów | 14 | Lustra orbitalne | `volcanic_awakening` | CO₂ zostaje w atmosferze na długo |
| Przerzedzanie | 6 | - | `cull_species` | mniej roślin to mniej tlenu |

Suma kosztów całego sklepu: 90 Iskier.

## Dochód

Iskry pochodzą z dwóch źródeł:

- bąbelki (główne): kliknięty bąbelek zasila konto w następnym ticku,
- dochód pasywny: co tick `income_per_biomass_tick × biomasa`, czyli
  `0,00001 × biomasa` (biomasa 0-100, więc co najwyżej 0,001 Iskry na tick).
  Mały dodatek, który nagradza bujne życie, ale nie zastępuje klikania.

## Bąbelki

| Rodzaj | Kiedy | Wartość |
|---|---|---|
| ambient | co 400 ticków | 1 |
| discovery | pojawił się nowy gatunek | 4 |
| bloom | gatunek pierwszy raz przekroczył populację 20, 40, 60 | 3 (raz na próg) |

Bąbelek żyje 15 sekund zegarowych (liczone, tylko gdy gra biegnie), na ekranie
jest ich najwyżej 8. Wartość bąbelka nie może przekroczyć 100 (tyle najwyżej
Iskier daje jedno przyznanie w `PerkSystem`); dane powyżej są odrzucane przy
wczytaniu. Pozycja jest czysto kosmetyczna: bąbelek pojawia się blisko tego
fragmentu globusa, który gracz akurat widzi (do 25° szerokości i 35°
długości od środka widoku), a w obrębie tej okolicy zależy od seeda i numeru
bąbelka. Na odwróconej stronie planety nie pojawia się prawie nic, bo
widać tylko ok. 31% kuli, a bąbelek żyje 15 s.

### Odstępstwo od specyfikacji (3.2)

Bąbelek ambient nie ma przyczyny w stanie planety: pojawia się co 400 ticków
niezależnie od tego, co robi życie. Specyfikacja (3.2) chce bąbelków, które
wynikają z planety. Ambient to zastępnik do czasu, aż pojawią się mutacje
(Etap 4) i inne zdarzenia, które same dają bąbelki; do tego czasu zostaje.


## Pomiar

Test `godot/simulation/tests/simulation/perk_economy_test.gd`: "doskonały
gracz" zbiera wszystkie bąbelki i co tick kupuje najtańszy dostępny perk.
30 000 ticków, tryb live, seedy 13 i 42. Granice testu: pierwszy zakup
do ticku 600; wszystkie 10 perków przed tickiem 30 000; 80-260 przyznanych
Iskier; 2,7-4,0 bąbelka na 1000 ticków (4-6 na minutę przy x25). Tempo x25 to 1500 ticków na minutę,
x50 to 3000.

Wartości z `ambient.every_ticks = 400` (aktualne dane):

| Seed | Pierwszy zakup | Wszystkie 10 perków | Iskry (bąbelki + pasywne) | Bąbelki | Na 1000 ticków | Na minutę x25 | Na minutę x50 |
|---|---|---|---|---|---|---|---|
| 13 | tick 131 | tick 18402 | 133,9 (130 + 3,9) | 91 | 3,03 | 4,55 | 9,10 |
| 42 | tick 123 | tick 11602 | 142,6 (133 + 9,6) | 92 | 3,07 | 4,60 | 9,20 |

Wcześniejsza wartość `every_ticks = 600` dawała 3,05 i 3,35 bąbelka na minutę
przy x25 (poniżej celu 4-6), więc ambient skrócono do 400. Cel 4-6 na minutę
jest mierzony przy domyślnym tempie x25 i jest spełniony; test
wymusza 2,7-4,0 bąbelka na 1000 ticków. Przy x50 bąbelków jest ok. 9 na minutę
i to jest przyjęte. Czy bąbelki ambient mają się pojawiać w czasie
rzeczywistym (niezależnie od tempa gry), rozstrzygnie Etap 3 razem z długością
partii.
Koszty perków nie wymagały zmian: całą półkę doskonały gracz kupuje w 11-18
tysięcy ticków z 30 000.

## Ograniczenia Etapu 1

- Wymagania perków dotyczą tylko innych perków (bez progów planety i bez
  wymagań od gatunków).
- Działanie `seed_species` (zasiew gatunku) jest darmowe i zawsze dostępne.
- Blokada działań perkami działa tylko w trybie live; tryb klasyczny
  (punkty decyzyjne) pozostaje bez blokad.
- Nie ma jeszcze Prób ani Gniewu Creatora (Etap 3), więc Iskry nie mają
  zagrożenia, przeciw któremu trzeba je wydać.
- Etap 1 ma 10 z ok. 20 planowanych perków. Doskonały gracz ma wszystkie w
  ticku ok. 11,6-18,4 tys., więc przez większość 72-tysięcznej partii Iskry
  niczego nie kupują, dopóki kolejne etapy nie dodadzą perków.
- Perk nie ma kosztu rosnącego z liczbą zakupów, drzewka Dyspersji ani
  Ekosystemu (kolejne etapy).

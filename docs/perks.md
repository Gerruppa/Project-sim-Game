# Iskry, bąbelki i perki

Pętla: z globusa wyskakują bąbelki, kliknięcie daje Iskry Życia, za Iskry
kupuje się perki w oknie perków (przycisk "Perks ✦" albo klawisz P; gra jest
wtedy spauzowana). Dane: `godot/resources/perks/perks.json` i
`godot/resources/bubbles/bubbles.json`. Kod: `PerkSystem`, `PerkCatalog`,
`BubbleField`, `GameSession` (tryb live), `PerkWindow`.

## Model perka (od 2026-10-07)

- **Gałąź** (`tree`): sześć gałęzi w oknie (lista `branches` w danych).
- **Linia i poziom** (`line`, `tier` 1-3): "Cold resistance I → II → III".
  Poziom wyższy wymaga poprzedniego tej samej linii (wymusza to loader) i
  kosztuje więcej.
- **Wymagania:** inne perki (`requires`) i gatunki, które musiały już żyć
  (`requires_species`; sprawdza je `GameSession.buy_perk`, nie symulacja).
- **Skutek uboczny:** każdy perk ma drugi modyfikator albo `income_scale`
  (tarcza spowalnia dochód Iskier). Zwrot oddaje 70% kosztu (w dół).
- Perk działa wyłącznie przez modyfikatory współczynników i odblokowane akcje.
- Start gry: 3 Iskry (`start_sparks`).

## Katalog (47 perków)

Koszty w Iskrach dla poziomów I / II / III.

| Gałąź | Linia | Koszt | Skutek na poziom | Skutek uboczny |
|---|---|---|---|---|
| Środowisko | Lustra, Pył, Zasiew chmur, Wody podziemne, Przebudzenie wulkanów (wymaga luster), Przerzedzanie | 8, 8, 10, 10, 14, 6 | odblokowują akcje | jak w opisie perka |
| Odporność | Hardiness | 4 / 9 | stres ×0,8 / ×0,85 | wzrost ×0,95 / ×0,97 |
| Odporność | Cold resistance | 5 / 9 / 15 | tolerancja zimna +3 / +3 / +4 | wzrost ×0,98 / ×0,98 / ×0,97 |
| Odporność | Heat resistance | 5 / 9 / 15 | tolerancja upału +3 / +3 / +4 | stres ×1,03 |
| Odporność | Drought resistance | 5 / 9 / 15 | mniejsza potrzeba wody +2 / +2 / +3 | pożary ×1,1 |
| Odporność | Fire resistance | 7 / 12 | pożary ×0,7 / ×0,6 | wzrost ×0,98 / ×0,97 |
| Rozsiew | Generous sowing | 5 / 9 / 15 | zasiew ×1,4 | stres ×1,03 / ×1,03 / ×1,04 |
| Rozsiew | Wind and wings | 6 / 11 | samoistny rozsiew ×1,5 | stres ×1,03 |
| Rozsiew | Regrowth | 8 / 13 | rekolonizacja +0,02 / +0,03 | stres ×1,05 |
| Produkcja | Fast growth | 8 / 12 / 18 | wzrost ×1,15 | stres ×1,05 / ×1,05 / ×1,06 |
| Produkcja | Fertile soil | 7 / 12 | pojemność ×1,1 | pożary ×1,1 |
| Produkcja | Oxygen factories | 8 / 14 | fotosynteza ×1,2 | pożary ×1,1 / ×1,15 |
| Tarcza | Creator's shield | 8 / 14 / 22 | siła kryzysów ×0,85 | dochód Iskier ×0,9 |
| Tarcza | Long peace | 10 / 16 | przerwy między kryzysami ×1,5 | dochód Iskier ×0,95 |
| Fauna | Lively animals | 6 / 10 / 16 | wzrost fauny ×1,3 | zjadają o 20% więcej |
| Fauna | Frugal feeders | 7 / 12 | potrzeba pokarmu ×0,8 | stres ×1,03 |
| Fauna | Pollinators | 9 / 15 | zapylanie +0,25 | zjadają o 10% więcej |
| Fauna | Migrations | 8 / 14 | samoistne pojawianie się fauny ×2 | stres ×1,03 |

Fauna wymaga, żeby owady już żyły (`requires_species`). Suma kosztów
katalogu to ok. 490 Iskier; bot zbiera ok. 140-165 i kupuje ok. 21 perków,
więc żadna ścieżka nie kupuje wszystkiego.

## Współczynniki dodane dla perków

Biosfera: `cold_tolerance`, `heat_tolerance`, `drought_tolerance` (skala
0-100), `seed_scale` (ile dodaje zasiew), `natural_seed_scale`,
`capacity_scale`, `photosynthesis_scale`, `fauna_growth_scale`,
`fauna_seed_scale`, `food_need_scale`, `graze_scale`, `pollination`.
Zdarzenia (`resources/events/event_config.json`): `severity` (ciągnie
modyfikatory kryzysu ku "bez zmian" w chwili jego startu) i
`cooldown_scale` (długość przerwy po kryzysie). Wartości domyślne są
neutralne.

## Dochód

- bąbelki (główne): kliknięty bąbelek zasila konto w następnym ticku, a przy
  zebraniu pojawia się "+N ✦",
- dochód pasywny: co tick `0,00001 × biomasa × income_scale` perków.

## Bąbelki

| Rodzaj | Kiedy | Wartość |
|---|---|---|
| ambient | co 400 ticków | 1 |
| discovery | pojawił się nowy gatunek (także zwierzęta) | 4 |
| bloom | gatunek pierwszy raz przekroczył populację 20, 40, 60 | 3 (raz na próg) |

Bąbelek żyje 15 sekund zegarowych (liczone tylko, gdy gra biegnie; okno
perków ją zatrzymuje), na ekranie jest ich najwyżej 8.

## Pomiar (narzędzia)

- `simulation/tests/simulation/perk_economy_test.gd`: doskonały gracz kupuje
  najtańszy dostępny perk; 30 000 ticków, seedy 13 i 42. Granice: pierwszy
  zakup do ticku 600, 12-28 perków, 80-260 Iskier, 2,7-4,0 bąbelka na 1000
  ticków. Zmierzone: pierwszy zakup tick 123-131, 19-20 perków, 140-147 Iskier.
- `simulation/tests/tools/game_length_report.gd`: bot gra całą partię live
  (zbiera bąbelki, kupuje najtańszy perk, sadzi kolejny szczebel drabiny,
  gdy przewodnik mówi "ideal"/"good"). 9 partii (3 seedy × 3 archetypy):
  9 wygranych, mediana wygranej tick 20 060 (rok 56; przy x25 to ok. 13 minut,
  przy x50 ok. 7), zakres 8 460-30 639, mediana 21 perków, pierwszy zakup
  w ticku 40. Człowiek będzie wolniejszy od bota; w Etapie 3 dojdą Próby, więc
  wygrane spadną.
- Jak stroić: `food_ticks` gatunków w `species.json` (czas do pojawienia się
  zwierząt), `for_ticks` celu w `goals.json`, wartości w `bubbles.json`,
  koszty perków (generowane z tabeli; po zmianie uruchomić testy katalogu).

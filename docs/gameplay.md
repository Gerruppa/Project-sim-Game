# Warstwa rozgrywki (krok 9)

Cel: gracz przechodzi pełną pętlę z `CORE_LOOP.md`:
obserwuje → stawia hipotezę → interweniuje → widzi konsekwencje z przyczynami.
Na etapie konsoli graczem jest obserwator kroniki.

---

# Ocena Fun Detectora (2026-10-05)

Dowody: kroniki seedów 7 i 13 (15 000 ticków). Planeta opowiada historie
(sukcesja, susze, krzewy wymierają i wracają 5 razy), ale kronika mówiła
„Wymierają drzewa” bez przyczyny: etap Hipotezy nie działał.

| Funkcja | Werdykt | Etap |
|---|---|---|
| Przyczyny wymierania w kronice | KEEP | 9a (zrobione) |
| Interwencje (5 akcji, cooldowny) | KEEP | 9b (zrobione) |
| Punkty decyzji (przebieg sam się zatrzymuje) | KEEP | 9c (zrobione) |
| Ambicje (opcjonalne cele z języka warunków) | POSTPONE | po 9c |
| Porównanie dwóch przyszłości z jednego zapisu (`lineage`) | POSTPONE | po 9c |
| Dziennik odkryć | POSTPONE | krok 10+ |
| Budynki (Master Plan, faza 7) | zostają w planie na później | decyzja użytkownika |

Czerwona flaga do pilnowania: akcja, która zawsze pomaga, staje się
optymalną strategią. Każda akcja musi mieć zmierzony negatywny skutek.

---

# Interwencje v1

| Akcja | Działanie | Zysk | Cena (emergentna) |
|---|---|---|---|
| Zasiej gatunek | biosfera: +populacja | skrót sukcesji | gatunek bez warunków umiera; wczesne drzewa to paliwo pożarów |
| Przerzedź gatunek | biosfera: zostaje 10% populacji | ratunek przed dominacją | spadek tlenu, pustka dla innych |
| Lustra orbitalne / pył | klimat: `base_temperature` ±8 przez 500 ticków | wyjście z lodowca lub upału | próg lód-albedo |
| Zasiew chmur | klimat: `rain_cloud_low` i `rain_cloud_high` −25 przez 300 ticków | deszcz z rzadszych chmur: krzewy i drzewa (żyją z opadów) | deszcz wyciąga wodę z powietrza: mchy i glony (żyją z wilgotności) cierpią |
| Wody podziemne | klimat: `evaporation_rate` ×2,5 przez 300 ticków | koniec suszy: wilgotność +4, opady +16 | więcej chmur ochładza planetę |
| Przebudzenie wulkanów | atmosfera: `volcanic_co2` ×3 przez 400 ticków | CO₂ dla roślin, ciepło | CO₂ zostaje długo |

Limit: cooldown na akcję. Bez waluty i punktów wpływu.

Zmiana względem projektu: zasiew chmur miał mnożyć `water_availability`
×1,2, ale ten współczynnik ma już wartość 1,0, czyli maksimum ze
specyfikacji, więc bez suszy nic by nie robił. Obniżony próg deszczu daje
prawdziwy dylemat między roślinami opadowymi a wilgotnościowymi.

Lustra to dwie akcje (`mirrors_warm`, `mirrors_cool`) ze wspólnym
cooldownem (`cooldown_group: mirrors`). Dane: `resources/interventions/interventions.json`.

---

# Architektura (9b, 9c)

```text
 konsola: --load zapis --act seed_species:moss --until decision
        │ Control (CommandQueue, faza Begin)
        ▼
 InterventionSystem (ModifierProvider)
   ├─ efekt "modifier" → ModifierRegistry (źródło player:<akcja>, czas trwania)
   ├─ efekt "species"  → polecenie do systemu "biosphere" (apply_command)
   ├─ stan: aktywne akcje, cooldowny → save_state / restore_modifiers
   └─ notyfikacje → kronika
 Runner: --until decision → stop + zapis przy world_event_started /
         species_extinct / species_emerged
```

- polecenia są danymi i częścią przebiegu: ten sam seed i te same
  polecenia dają ten sam wynik; trafiają do zapisu i logu
- InterventionSystem nie zna konkretnych systemów: cele w danych
- zasiew zmienia populacje biosfery, nie stan planety (biomasa dalej
  wynika z populacji)
- później UI wysyła te same polecenia do tej samej kolejki

---

# Implementacja 9b

- `SimCommand` i `CommandQueue` (`simulation/core/`): polecenie to dane
  (`tick`, `target`, `action`, `args`, `sequence`); kolejka wydaje je
  w fazie 1 (Begin) w kolejności zgłoszenia i jest częścią zapisu gry
- `SimulationSystem.validate_command` / `apply_command`: system sprawdza
  polecenie przy zgłoszeniu (`SimulationManager.submit`), więc zły
  rozkaz kończy się błędem od razu, a nie ticki później;
  `apply_command` może zwrócić polecenia następcze dla innych systemów
- `InterventionSystem` (`simulation/interventions/`, ModifierProvider):
  cooldowny, modyfikatory z `expires_at`, polecenia następcze, zdarzenia
  `intervention_applied` / `intervention_ended` / `intervention_rejected`,
  zapis aktywnych interwencji i cooldownów
- `BiosphereSystem.COMMANDS`: `add_population`, `scale_population`;
  przerzedzenie poniżej progu wymierania oznacza wymarcie z przyczyną
  `culled` („przerzedziła je ręka gracza”)
- zdarzenia z fazy Begin są publikowane przed zdarzeniami systemów:
  „Gracz zasiewa mchy.” stoi w kronice przed „Pojawiają się mchy.”
- konsola: `--act NAZWA[:ARG][:POZIOM]` (powtarzalne), np.
  `--load epoka.json --act seed_species:moss --ticks 2000`
- pomiar zabawy: `simulation/tests/tools/intervention_report.gd`

# Implementacja 9c: punkty decyzji

Pętla gracza w konsoli:

```bash
./godot/run_simulation.sh --until decision --story                      # do pierwszego punktu decyzji
./godot/run_simulation.sh --load decision.json --act cull_species:shrub --until decision --story
```

- punkt decyzji: pierwsze zdarzenie z `decision_points.events`
  (`interventions.json`: początek zdarzenia świata, wymarcie, pojawienie
  się gatunku) po okresie ochronnym `grace_ticks` (100) od startu
  przebiegu; okres ochronny sprawia, że gracz najpierw widzi skutki
  własnej akcji (zasiane mchy „pojawiają się” w pierwszym ticku)
- przebieg kończy się po ticku punktu decyzji (w czasie rzeczywistym:
  po klatce, w której wypadł), zapisuje się do `saves/decision.json`
  (albo `--save PLIK`) i pokazuje: zdania kroniki z tego ticku,
  interwencje z gotowością („gotowe” / „od ticku N”), populacje
  gatunków i komendę, która kontynuuje
- stała nazwa zapisu: pętla to zawsze ta sama komenda
- `DecisionWatcher` (`tools/`) tylko obserwuje; `--ticks` jest limitem

# Pomiar (intervention_report.gd)

3 archetypy × 3 seedy, akcja w ticku 2500, obserwacja do 6500, porównanie
z tym samym przebiegiem bez akcji (wczytanym z jednego zapisu). Cena: więcej
wymierań, mniej żywych gatunków lub o >5% mniej biomasy; zysk: odwrotnie.

| Akcja | Zmienia kronikę | Cena | Zysk | Śr. Δ biomasy | Śr. ΔT |
|---|---|---|---|---|---|
| Zasiew krzewów | 9/9 | 4 | 1 | +0,02 | +0,03 |
| Zasiew drzew | 9/9 | 9 | 0 | 0,00 | +0,01 |
| Przerzedzenie mchów (10%) | 9/9 | 0 | 0 | −0,05 | −0,20 |
| Lustra ±8 (ogrzewanie) | 9/9 | 4 | 0 | −0,07 | +0,72 |
| Pył ±8 (chłodzenie) | 9/9 | 4 | 3 | +0,29 | −1,35 |
| Zasiew chmur (−25) | 9/9 | 2 | 0 | −0,07 | −0,03 |
| Przebudzenie wulkanów | 9/9 | 1 | 4 | +0,71 | +1,53 |

Przed strojeniem (lustra ±4, przerzedzenie do 50%, chmury −15) lustra
i zasiew chmur prawie nie miały ceny, a pył i wulkany już były dylematami.
Żadna akcja nie jest najlepsza zawsze. Otwarte:

- przerzedzenie mchów nie ma skutku po 4000 tickach: mchy odrastają
  z glonów (poprzednik zasiewa je stale); przerzedzenie ma sens jako
  reakcja na kryzys (np. krzewy przed pożarem), co wymaga punktów decyzji
- lustra ogrzewające nie dały zysku w żadnej próbie, bo w ticku 2500
  planety są ciepłe (~30°); ich miejsce to epoka lodowa, której próba
  nie obejmuje
- zasiew drzew w ticku 2500 zawsze zawodzi (za mało tlenu i gleby):
  zostawione celowo, bo kronika mówi dlaczego

## Pomiar w punktach decyzji (`--at decision`)

Ta sama próba, ale akcja zapada w pierwszym kryzysie po ticku 1500
(w 7 z 9 przebiegów to początek suszy, w 2 wymarcie gatunku), czyli
tam, gdzie gracz naprawdę decyduje. Obserwacja: 4000 ticków.

| Akcja | Zmienia kronikę | Cena | Zysk | Śr. Δ biomasy | Śr. ΔT |
|---|---|---|---|---|---|
| Zasiew krzewów | 9/9 | 5 | 0 | +0,04 | +0,03 |
| Zasiew drzew | 9/9 | 9 | 0 | 0,00 | +0,01 |
| Przerzedzenie mchów | 8/9 | 1 | 0 | −0,08 | −0,05 |
| Przerzedzenie krzewów | 4/9 | 0 | 0 | −0,03 | −0,01 |
| Lustra (+8) | 9/9 | 5 | 1 | −0,26 | +0,92 |
| Pył (−8) | 9/9 | 5 | 0 | −0,35 | −2,12 |
| Zasiew chmur | 9/9 | 2 | 0 | −0,13 | +0,04 |
| Przebudzenie wulkanów | 9/9 | 1 | 1 | +0,29 | +1,53 |

Wniosek: w kryzysie prawie każda akcja kosztuje, a prawie żadna nie
pomaga. Gracz w suszy nie ma dobrego ruchu, więc to nie jest dylemat,
tylko kara za działanie. Dwie przyczyny:

- planeta jest silnie samoregulująca (termostat węglowy, odrastanie
  gatunków): po 4000 tickach różnice w biomasie są rzędu 1%
- żadna akcja nie celuje w suszę: zasiew chmur obniża próg deszczu, ale
  susza to spadek wilgotności, której deszcz jeszcze ubywa

Przerzedzenie krzewów zmieniło kronikę tylko w 4/9, bo w momencie kryzysu
krzewów często jeszcze nie ma (raport punktu decyzji pokazuje populacje,
więc gracz to widzi). Jedyny zysk luster: chaotyczna planeta seed 3,
chłodna (24°), gdzie ciepło uratowało gatunek.

# Tłumienie: dlaczego decyzje „znikają” (pomiar 2026-10-05)

`planet_report.gd --limits` (3 archetypy × 4 seedy × 15 000 ticków): żaden
parametr nie spędza czasu przy górnej granicy (0%); CO₂ dotknęło 98 tylko
chwilowo. Przy dolnej granicy bywają wyłącznie opady (do 26% czasu, epoki
lodowe). Soft capy nie są potrzebne. Planeta żyje w wąskich pasmach:
wilgotność 17-40, zachmurzenie 30-51.

`intervention_trace.gd` (akcja w pierwszym kryzysie, 9 przebiegów,
różnica z przebiegiem bez akcji tick po ticku):

| Akcja | Szczyt ΔT | Szczyt Δ biomasy | Szczyt Δ populacji | Skutek trwa (ticki) |
|---|---|---|---|---|
| Pył (−8) | 25,3 po 256 | 19,1 | mchy 61,7, glony 56,1 | 1270-2600 |
| Lustra (+8) | 19,7 po 301 | 16,2 | mchy 59,9 | 1490-2400 |
| Wulkany | 16,1 po 1033 | 9,8 | mchy 35,6 | 1560-2580 |
| Zasiew chmur | 7,5 | 10,6 | mchy 31,6 | 660-2410 |
| Wody podziemne (×2,5) | 4,6 | 4,0 | mchy 12,8, krzewy 11,0 | 580-2460 |
| Przerzedzenie mchów | 1,9 | 6,9 | mchy 40,2 | 680-2200 |

Wniosek: planeta **nie tłumi** akcji, tylko **wszystko wybacza**.
Krótkoterminowo reaguje mocno (lód-albedo wzmacnia −8° do 25°), po
1000-2500 tickach wraca do stanu sprzed akcji. Dwa mechanizmy powrotu:

- obieg wody: więcej parowania → więcej chmur → więcej deszczu, który
  zabiera wodę z powietrza (dlatego wody podziemne potrzebują ×2,5)
- wymarcie nie jest trwałe: poprzednik stale zasiewa gatunek, który wraca
  sam (mchy po 190-410 tickach, krzewy po 340-2700, drzewa po 1400-3000)

Pomiar „stan po 4000 tickach” mierzył więc zły horyzont. Ocena akcji
(`intervention_report.gd`) liczy teraz średnie w oknie 2000 ticków po akcji.

# Groźniejsze kryzysy (decyzja A, 2026-10-05)

`event_impact.gd` porównuje przebieg ze zdarzeniami z tym samym bez nich
(3 archetypy × 3 seedy × 8000 ticków, 37 susz, średnio ~200 ticków):

| Susza | Δ wilgotności | Δ biomasy | Δ mchów | Wymierania (z / bez) |
|---|---|---|---|---|
| tylko woda ×0,85 (stara) | ~−0,5 | 0,0 | ~+1 | 12 / 12 |
| woda ×0,6 | −0,85 | −0,01 | +1,4 | 12 / 12 |
| woda ×0,6, wzrost ×0,6, pożary ×2 | −0,27 | **−2,09** | **−7,0** | 11 / 12 |

Ocena akcji w pierwszym kryzysie (średnie z 2000 ticków po akcji):

| Akcja | Cena | Zysk | Śr. Δ biomasy |
|---|---|---|---|
| Wody podziemne | 1 | 2 | −0,44 |
| Wulkany | 2 | 2 | −0,50 |
| Zasiew krzewów | 5 | 2 | +0,52 |
| Lustra (+8) | 7 | 1 | −4,72 |
| Pył (−8) | 7 | 0 | −6,24 |
| Zasiew chmur | 6 | 0 | −2,25 |

Pierwszy dobry ruch zależny od kontekstu: wody podziemne w suszy dają
zysk albo są neutralne w 6 z 7 susz (na chaotycznej planecie seed 3
uratowały gatunek), a w kryzysie innego typu (wymarcie krzewów) szkodzą
(−7 biomasy). Zasiew chmur w suszy szkodzi: deszcz wysusza powietrze.
Gracz musi rozpoznać kryzys, żeby dobrać narzędzie.

Lustra i pył były w kryzysie prawie zawsze szkodliwe (młot zamiast
skalpela); rozwiązane poziomami siły (opcja C, niżej).

## Czy zasiew wymarłego gatunku daje zysk? (pomiar 2026-10-05)

`intervention_report.gd --at extinction`: akcja w pierwszym wymarciu po
ticku 1500, `seed_species:$extinct` zasiewa właśnie ten gatunek.
3 archetypy × 5 seedów, 14 przebiegów z wymarciem, średnie z 2000 ticków.

| Akcja przy wymarciu | Cena | Zysk | Śr. Δ biomasy |
|---|---|---|---|
| Zasiew wymarłego gatunku | 6 | 8 | +1,79 |
| Lustra lekko | 4 | 6 | +0,21 |
| Wody podziemne | 2 | 1 | −0,09 |

- mchy: zysk w 7 z 8 przypadków (np. chaotyczna seed 4: średnio 3,0
  żyjących gatunków zamiast 2,0; harmonijna seed 2, krzewy: biomasa
  25,6 zamiast 15,9)
- krzewy i drzewa często giną ponownie: wszystkie 6 „cen” to ponowne
  wymarcie zasianego gatunku, bo przyczyna (chłód, susza) nadal działa;
  żyjących gatunków nie ubywa, więc nieudany zasiew jest lekcją, nie stratą

To jest pętla warstwy rozgrywki: gracz czyta przyczynę w kronice
(„Wymierają krzewy: za zimno.”), ocenia, czy minęła, i dopiero wtedy sieje.

### Ryzyko: odruch „zawsze zasiej, co wymarło”

Zasiew prawie nigdy nie szkodzi, a często pomaga, więc może stać się
optymalną strategią zamiast decyzji. Dziś ogranicza go tylko cooldown
(300 ticków) i ryzyko zmarnowania. Sygnał nadużycia: w kronikach graczy
zasiew pojawia się po prawie każdym wymarciu, niezależnie od przyczyny.
Możliwe poprawki, od najprostszej:

1. **Dłuższy cooldown** (np. 300 → 800 ticków): jedna linijka w danych;
   wymusza wybór, który gatunek przywrócić, ale nie uczy niczego nowego.
2. **Cena w stanie planety**: zasiew zużywa część biomasy innego gatunku
   (np. poprzednika) albo tlenu; przywrócenie ma koszt, który widać
   w kronice i który może wywołać kolejny kryzys.
3. **Słabszy zasiew w złych warunkach**: zasiana populacja zależy od
   przydatności środowiska (`amount × suitability`), więc siew wbrew
   przyczynie wymarcia daje prawie nic; nagradza czytanie przyczyny
   zamiast odruchu.
4. **Malejące przychody** (wzór G z analizy soft capów):
   `siła = bazowa / (1 + 0,5 · n)`, n = zasiewy tego gatunku w ostatnich
   2000 ticków; kronika może to opowiedzieć („mchy słabo się przyjmują”).
5. **Bank nasion**: ograniczona liczba zasiewów, odnawiana np. przy
   pojawieniu się nowego gatunku; najsilniejsza zmiana, wprowadza zasób,
   więc dopiero gdy 1-4 nie wystarczą (DESIGN_PRINCIPLES: brak ekonomii
   zasobów jako celu).

Rekomendacja: najpierw 3 (najbardziej „ekologiczna”, wzmacnia pętlę
obserwacji), potem 1 jako regulacja tempa. Wprowadzać dopiero po
zobaczeniu nadużycia w prawdziwej grze.

# Poziomy siły (decyzja C, 2026-10-05)

Interwencja z modyfikatorami może mieć `levels` w danych:
`{"default": id, "options": {id: {"scale": 0..1, "name": słowo do kroniki}}}`.
Gracz wybiera poziom po dwukropku: `--act mirrors_cool:weak`; bez poziomu
działa domyślny. Skalowanie: `add` → wartość × skala, `multiply` →
1 + (wartość − 1) × skala, więc słabszy poziom leży zawsze między „nic”
a pełną siłą. Cooldown i czas trwania są wspólne: gracz wybiera dawkę,
nie częstotliwość. Kronika: „Gracz rozpyla pył na orbicie (lekko): …”.

Lustra i pył mają poziomy `weak` (0,25 → ±2°), `medium` (0,5 → ±4°)
i `strong` (1,0 → ±8°, domyślny). Pomiar w pierwszym kryzysie
(9 przebiegów, średnie z 2000 ticków po akcji):

| Akcja | Cena | Zysk | Śr. Δ biomasy |
|---|---|---|---|
| Lustra lekko (+2) | 3 | 4 | +0,08 |
| Lustra umiarkowanie (+4) | 6 | 4 | −1,70 |
| Lustra z pełną mocą (+8) | 8 | 1 | −4,60 |
| Pył lekko (−2) | 4 | 2 | −1,13 |
| Pył umiarkowanie (−4) | 5 | 2 | −2,12 |
| Pył z pełną mocą (−8) | 7 | 0 | −5,74 |

Lekkie lustra są prawdziwym dylematem (zysk 4, cena 3), a ryzyko rośnie
z siłą. Pełna moc zostaje na sytuacje, w których planeta naprawdę musi się
zmienić (np. wyjście z epoki lodowej).

# Trwałe wymieranie (decyzja B, 2026-10-05)

Wymarły gatunek wraca sam tylko z ułamkiem dawnego zasiewu
(`recolonization` 0,01, `docs/biosphere.md`), a gracz może go przywrócić
zasiewem („Wracają krzewy.”). Raport punktu decyzji oznacza gatunki
„(wymarłe)”. Przy 0 planeta bez gracza często utyka we wczesnym życiu na
zawsze; przy 0,05 powroty były tylko 1,3-6 razy wolniejsze. Wybrano 0,01:
ślad decyzji trwa tysiące ticków (krzewy na seedzie 13 nie wróciły przez
ponad 10 000), a planeta dalej się natlenia i rozwija.

# Kryteria akceptacji

- każde wymieranie w kronice ma przyczynę (9a)
- każda akcja zmienia kronikę w ≥2 z 3 seedów i ma zmierzony
  negatywny skutek; żadna nie jest najlepsza na wszystkich archetypach
- zapis z aktywną interwencją wznawia się bit w bit
- punkt decyzji zatrzymuje przebieg i zostawia zapis

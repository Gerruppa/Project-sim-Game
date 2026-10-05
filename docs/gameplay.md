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
| Punkty decyzji (przebieg sam się zatrzymuje) | KEEP | 9c |
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
- konsola: `--act NAZWA[:ARG]` (powtarzalne), np.
  `--load epoka.json --act seed_species:moss --ticks 2000`
- pomiar zabawy: `simulation/tests/tools/intervention_report.gd`

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

# Kryteria akceptacji

- każde wymieranie w kronice ma przyczynę (9a)
- każda akcja zmienia kronikę w ≥2 z 3 seedów i ma zmierzony
  negatywny skutek; żadna nie jest najlepsza na wszystkich archetypach
- zapis z aktywną interwencją wznawia się bit w bit
- punkt decyzji zatrzymuje przebieg i zostawia zapis
